//
//  FTCrashReportC.c
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "FTCrashReportC.h"

#include "FTCrashBinaryImageCache.h"
#include "FTCrashCPU.h"
#include "FTCrashExceptionHandlingPlan.h"
#include "FTCrashMonitorHelper.h"
#include "FTCrashMonitor_AppState.h"
#include "FTCrashMonitor_CPPException.h"
#include "FTCrashMonitor_MachException.h"
#include "FTCrashMonitor_NSException.h"
#include "FTCrashMonitor_Signal.h"
#include "FTCrashMonitor_System.h"
#include "FTCrashReportFields.h"
#include "FTCrashReportVersion.h"
#include "FTCrashReportWriter.h"
#include "FTCrashReportWriterCallbacks.h"
#include "FTCrashDate.h"
#include "FTCrashDynamicLinker.h"
#include "FTCrashFileUtils.h"
#include "FTCrashJSONCodec.h"
#include "FTCrashMach.h"
#include "FTCrashMemory.h"
#include "FTCrashObjC.h"
#include "FTCrashSignalInfo.h"
#include "FTCrashStackCursor_Backtrace.h"
#include "FTCrashStackCursor_MachineContext.h"
#include "FTCrashString.h"
#include "FTSDKCompat.h"
#include "FTCrashThread.h"
#include "FTCrashThreadCache.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "FTCrashLogger.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

/** Default number of objects, subobjects, and ivars to record from a memory loc */
#define kDefaultMemorySearchDepth 15

/** How far to search the stack (in pointer sized jumps) for notable data. */
#define kStackNotableSearchBackDistance 20
#define kStackNotableSearchForwardDistance 10

/** How much of the stack to dump (in pointer sized jumps). */
#define kStackContentsPushedDistance 20
#define kStackContentsPoppedDistance 10
#define kStackContentsTotalDistance (kStackContentsPushedDistance + kStackContentsPoppedDistance)

/** The minimum length for a valid string. */
#define kMinStringLength 4

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

#define getJsonContext(REPORT_WRITER) ((FTCrashJSONEncodeContext *)((REPORT_WRITER)->context))

/** Used for writing hex string values. */
static const char g_hexNybbles[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

// ============================================================================
#pragma mark - Runtime Config -
// ============================================================================

typedef struct {
    /** If YES, introspect memory contents during a crash.
     * Any Objective-C objects or C strings near the stack pointer or referenced by
     * cpu registers or exceptions will be recorded in the crash report, along with
     * their contents.
     */
    bool enabled;

    /** List of classes that should never be introspected.
     * Whenever a class in this list is encountered, only the class name will be recorded.
     */
    const char **restrictedClasses;
    int restrictedClassesCount;
} FTCrash_IntrospectionRules;

static const char *g_userInfoJSON;
static pthread_mutex_t g_userInfoMutex = PTHREAD_MUTEX_INITIALIZER;

static FTCrash_IntrospectionRules g_introspectionRules;
static FTCrashIsWritingReportCallback g_userSectionWriteCallback;

#pragma mark Callbacks

static void addBooleanElement(const FTCrashReportWriter *const writer, const char *const key, const bool value)
{
    ftcrashjson_addBooleanElement(getJsonContext(writer), key, value);
}

static void addFloatingPointElement(const FTCrashReportWriter *const writer, const char *const key, const double value)
{
    ftcrashjson_addFloatingPointElement(getJsonContext(writer), key, value);
}

static void addIntegerElement(const FTCrashReportWriter *const writer, const char *const key, const int64_t value)
{
    ftcrashjson_addIntegerElement(getJsonContext(writer), key, value);
}

static void addUIntegerElement(const FTCrashReportWriter *const writer, const char *const key, const uint64_t value)
{
    ftcrashjson_addUIntegerElement(getJsonContext(writer), key, value);
}

static void addStringElement(const FTCrashReportWriter *const writer, const char *const key, const char *const value)
{
    ftcrashjson_addStringElement(getJsonContext(writer), key, value, FTCRASHJSON_SIZE_AUTOMATIC);
}

static void addTextFileElement(const FTCrashReportWriter *const writer, const char *const key,
                               const char *const filePath)
{
    const int fd = open(filePath, O_RDONLY);
    if (fd < 0) {
        FTLOG_ERROR("Could not open file %s: %s", filePath, strerror(errno));
        return;
    }

    if (ftcrashjson_beginStringElement(getJsonContext(writer), key) != FTCRASHJSON_OK) {
        FTLOG_ERROR("Could not start string element");
        goto done;
    }

    char buffer[512];
    int bytesRead;
    for (bytesRead = (int)read(fd, buffer, sizeof(buffer)); bytesRead > 0;
         bytesRead = (int)read(fd, buffer, sizeof(buffer))) {
        if (ftcrashjson_appendStringElement(getJsonContext(writer), buffer, bytesRead) != FTCRASHJSON_OK) {
            FTLOG_ERROR("Could not append string element");
            goto done;
        }
    }

done:
    ftcrashjson_endStringElement(getJsonContext(writer));
    close(fd);
}

static void addDataElement(const FTCrashReportWriter *const writer, const char *const key, const char *const value,
                           const int length)
{
    ftcrashjson_addDataElement(getJsonContext(writer), key, value, length);
}

static void beginDataElement(const FTCrashReportWriter *const writer, const char *const key)
{
    ftcrashjson_beginDataElement(getJsonContext(writer), key);
}

static void appendDataElement(const FTCrashReportWriter *const writer, const char *const value, const int length)
{
    ftcrashjson_appendDataElement(getJsonContext(writer), value, length);
}

static void endDataElement(const FTCrashReportWriter *const writer) { ftcrashjson_endDataElement(getJsonContext(writer)); }

static void addUUIDElement(const FTCrashReportWriter *const writer, const char *const key,
                           const unsigned char *const value)
{
    if (value == NULL) {
        ftcrashjson_addNullElement(getJsonContext(writer), key);
    } else {
        char uuidBuffer[37];
        const unsigned char *src = value;
        char *dst = uuidBuffer;
        for (int i = 0; i < 4; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 6; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }

        ftcrashjson_addStringElement(getJsonContext(writer), key, uuidBuffer, (int)(dst - uuidBuffer));
    }
}

static void addJSONElement(const FTCrashReportWriter *const writer, const char *const key,
                           const char *const jsonElement, bool closeLastContainer)
{
    int jsonResult =
        ftcrashjson_addJSONElement(getJsonContext(writer), key, jsonElement, (int)strlen(jsonElement), closeLastContainer);
    if (jsonResult != FTCRASHJSON_OK) {
        char errorBuff[100];
        snprintf(errorBuff, sizeof(errorBuff), "Invalid JSON data: %s", ftcrashjson_stringForError(jsonResult));
        ftcrashjson_beginObject(getJsonContext(writer), key);
        ftcrashjson_addStringElement(getJsonContext(writer), FTCrashField_Error, errorBuff, FTCRASHJSON_SIZE_AUTOMATIC);
        ftcrashjson_addStringElement(getJsonContext(writer), FTCrashField_JSONData, jsonElement, FTCRASHJSON_SIZE_AUTOMATIC);
        ftcrashjson_endContainer(getJsonContext(writer));
    }
}

static void addJSONElementFromFile(const FTCrashReportWriter *const writer, const char *const key,
                                   const char *const filePath, bool closeLastContainer)
{
    ftcrashjson_addJSONFromFile(getJsonContext(writer), key, filePath, closeLastContainer);
}

static void beginObject(const FTCrashReportWriter *const writer, const char *const key)
{
    ftcrashjson_beginObject(getJsonContext(writer), key);
}

static void beginArray(const FTCrashReportWriter *const writer, const char *const key)
{
    ftcrashjson_beginArray(getJsonContext(writer), key);
}

static void endContainer(const FTCrashReportWriter *const writer) { ftcrashjson_endContainer(getJsonContext(writer)); }

static void addTextLinesFromFile(const FTCrashReportWriter *const writer, const char *const key,
                                 const char *const filePath)
{
    char readBuffer[1024];
    FTCrashBufferedReader reader;
    if (!ftcrashfu_openBufferedReader(&reader, filePath, readBuffer, sizeof(readBuffer))) {
        return;
    }
    char buffer[1024];
    beginArray(writer, key);
    {
        for (;;) {
            int length = sizeof(buffer);
            ftcrashfu_readBufferedReaderUntilChar(&reader, '\n', buffer, &length);
            if (length <= 0) {
                break;
            }
            buffer[length - 1] = '\0';
            ftcrashjson_addStringElement(getJsonContext(writer), NULL, buffer, FTCRASHJSON_SIZE_AUTOMATIC);
        }
    }
    endContainer(writer);
    ftcrashfu_closeBufferedReader(&reader);
}

static int addJSONData(const char *restrict const data, const int length, void *restrict userData)
{
    FTCrashBufferedWriter *writer = (FTCrashBufferedWriter *)userData;
    const bool success = ftcrashfu_writeBufferedWriter(writer, data, length);
    return success ? FTCRASHJSON_OK : FTCRASHJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Check if a memory address points to a valid null terminated UTF-8 string.
 *
 * @param address The address to check.
 *
 * @return true if the address points to a string.
 */
static bool isValidString(const void *const address)
{
    if ((void *)address == NULL) {
        return false;
    }

    char buffer[500];
    if ((uintptr_t)address + sizeof(buffer) < (uintptr_t)address) {
        // Wrapped around the address range.
        return false;
    }
    if (!ftcrashmem_copySafely(address, buffer, sizeof(buffer))) {
        return false;
    }
    return ftcrashstring_isNullTerminatedUTF8String(buffer, kMinStringLength, sizeof(buffer));
}

/** Get the backtrace for the specified machine context.
 *
 * This function will choose how to fetch the backtrace based on the crash and
 * machine context. It may store the backtrace in backtraceBuffer unless it can
 * be fetched directly from memory. Do not count on backtraceBuffer containing
 * anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The machine context.
 *
 * @param cursor The stack cursor to fill.
 *
 * @return True if the cursor was filled.
 */
static bool getStackCursor(const FTCrash_MonitorContext *const crash,
                           const struct FTCrashMachineContext *const machineContext, FTCrashStackCursor *cursor)
{
    if (ftcrashmc_getThreadFromContext(machineContext) == ftcrashmc_getThreadFromContext(crash->offendingMachineContext) &&
        crash->stackCursor != NULL) {
        *cursor = *((FTCrashStackCursor *)crash->stackCursor);
        return true;
    }

    ftcrashsc_initWithMachineContext(cursor, FTCRASHSC_STACK_OVERFLOW_THRESHOLD, machineContext);
    return true;
}

// ============================================================================
#pragma mark - Report Writing -
// ============================================================================

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const FTCrashReportWriter *const writer, const char *const key, const uintptr_t address,
                                int *limit);

/** Write a string to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNSStringContents(const FTCrashReportWriter *const writer, const char *const key,
                                  const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (ftcrashobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a URL to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeURLContents(const FTCrashReportWriter *const writer, const char *const key,
                             const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (ftcrashobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a date to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeDateContents(const FTCrashReportWriter *const writer, const char *const key,
                              const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, ftcrashobjc_dateContents(object));
}

/** Write a number to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNumberContents(const FTCrashReportWriter *const writer, const char *const key,
                                const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, ftcrashobjc_numberAsFloat(object));
}

/** Write an array to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeArrayContents(const FTCrashReportWriter *const writer, const char *const key,
                               const uintptr_t objectAddress, int *limit)
{
    const void *object = (const void *)objectAddress;
    uintptr_t firstObject;
    if (ftcrashobjc_arrayContents(object, &firstObject, 1) == 1) {
        writeMemoryContents(writer, key, firstObject, limit);
    }
}

/** Write out ivar information about an unknown object.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeUnknownObjectContents(const FTCrashReportWriter *const writer, const char *const key,
                                       const uintptr_t objectAddress, int *limit)
{
    (*limit)--;
    const void *object = (const void *)objectAddress;
    FTCrashObjCIvar ivars[10];
    int8_t s8;
    int16_t s16;
    int sInt;
    int32_t s32;
    int64_t s64;
    uint8_t u8;
    uint16_t u16;
    unsigned int uInt;
    uint32_t u32;
    uint64_t u64;
    float f32;
    double f64;
    bool b;
    void *pointer;

    writer->beginObject(writer, key);
    {
        if (ftcrashobjc_isTaggedPointer(object)) {
            writer->addIntegerElement(writer, "tagged_payload", (int64_t)ftcrashobjc_taggedPointerPayload(object));
        } else {
            const void *class = ftcrashobjc_isaPointer(object);
            int ivarCount = ftcrashobjc_ivarList(class, ivars, sizeof(ivars) / sizeof(*ivars));
            *limit -= ivarCount;
            for (int i = 0; i < ivarCount; i++) {
                FTCrashObjCIvar *ivar = &ivars[i];
                switch (ivar->type[0]) {
                    case 'c':
                        ftcrashobjc_ivarValue(object, ivar->index, &s8);
                        writer->addIntegerElement(writer, ivar->name, s8);
                        break;
                    case 'i':
                        ftcrashobjc_ivarValue(object, ivar->index, &sInt);
                        writer->addIntegerElement(writer, ivar->name, sInt);
                        break;
                    case 's':
                        ftcrashobjc_ivarValue(object, ivar->index, &s16);
                        writer->addIntegerElement(writer, ivar->name, s16);
                        break;
                    case 'l':
                        ftcrashobjc_ivarValue(object, ivar->index, &s32);
                        writer->addIntegerElement(writer, ivar->name, s32);
                        break;
                    case 'q':
                        ftcrashobjc_ivarValue(object, ivar->index, &s64);
                        writer->addIntegerElement(writer, ivar->name, s64);
                        break;
                    case 'C':
                        ftcrashobjc_ivarValue(object, ivar->index, &u8);
                        writer->addUIntegerElement(writer, ivar->name, u8);
                        break;
                    case 'I':
                        ftcrashobjc_ivarValue(object, ivar->index, &uInt);
                        writer->addUIntegerElement(writer, ivar->name, uInt);
                        break;
                    case 'S':
                        ftcrashobjc_ivarValue(object, ivar->index, &u16);
                        writer->addUIntegerElement(writer, ivar->name, u16);
                        break;
                    case 'L':
                        ftcrashobjc_ivarValue(object, ivar->index, &u32);
                        writer->addUIntegerElement(writer, ivar->name, u32);
                        break;
                    case 'Q':
                        ftcrashobjc_ivarValue(object, ivar->index, &u64);
                        writer->addUIntegerElement(writer, ivar->name, u64);
                        break;
                    case 'f':
                        ftcrashobjc_ivarValue(object, ivar->index, &f32);
                        writer->addFloatingPointElement(writer, ivar->name, f32);
                        break;
                    case 'd':
                        ftcrashobjc_ivarValue(object, ivar->index, &f64);
                        writer->addFloatingPointElement(writer, ivar->name, f64);
                        break;
                    case 'B':
                        ftcrashobjc_ivarValue(object, ivar->index, &b);
                        writer->addBooleanElement(writer, ivar->name, b);
                        break;
                    case '*':
                    case '@':
                    case '#':
                    case ':':
                        ftcrashobjc_ivarValue(object, ivar->index, &pointer);
                        writeMemoryContents(writer, ivar->name, (uintptr_t)pointer, limit);
                        break;
                    default:
                        FTLOG_DEBUG("%s: Unknown ivar type [%s]", ivar->name, ivar->type);
                }
            }
        }
    }
    writer->endContainer(writer);
}

static bool isRestrictedClass(const char *name)
{
    if (g_introspectionRules.restrictedClasses != NULL) {
        for (int i = 0; i < g_introspectionRules.restrictedClassesCount; i++) {
            if (ftcrashstring_safeStrcmp(name, g_introspectionRules.restrictedClasses[i]) == 0) {
                return true;
            }
        }
    }
    return false;
}


static bool writeObjCObject(const FTCrashReportWriter *const writer, const uintptr_t address, int *limit)
{
#if FT_HAS_OBJC
    const void *object = (const void *)address;
    switch (ftcrashobjc_objectType(object)) {
        case FTCrashObjCTypeClass:
            writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_Class);
            writer->addStringElement(writer, FTCrashField_Class, ftcrashobjc_className(object));
            return true;
        case FTCrashObjCTypeObject: {
            writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_Object);
            const char *className = ftcrashobjc_objectClassName(object);
            writer->addStringElement(writer, FTCrashField_Class, className);
            if (!isRestrictedClass(className)) {
                switch (ftcrashobjc_objectClassType(object)) {
                    case FTCrashObjCClassTypeString:
                        writeNSStringContents(writer, FTCrashField_Value, address, limit);
                        return true;
                    case FTCrashObjCClassTypeURL:
                        writeURLContents(writer, FTCrashField_Value, address, limit);
                        return true;
                    case FTCrashObjCClassTypeDate:
                        writeDateContents(writer, FTCrashField_Value, address, limit);
                        return true;
                    case FTCrashObjCClassTypeArray:
                        if (*limit > 0) {
                            writeArrayContents(writer, FTCrashField_FirstObject, address, limit);
                        }
                        return true;
                    case FTCrashObjCClassTypeNumber:
                        writeNumberContents(writer, FTCrashField_Value, address, limit);
                        return true;
                    case FTCrashObjCClassTypeDictionary:
                    case FTCrashObjCClassTypeException:
                        // TODO: Implement these.
                        if (*limit > 0) {
                            writeUnknownObjectContents(writer, FTCrashField_Ivars, address, limit);
                        }
                        return true;
                    case FTCrashObjCClassTypeUnknown:
                        if (*limit > 0) {
                            writeUnknownObjectContents(writer, FTCrashField_Ivars, address, limit);
                        }
                        return true;
                    default:
                        break;
                }
            }
            break;
        }
        case FTCrashObjCTypeBlock:
            writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_Block);
            const char *className = ftcrashobjc_objectClassName(object);
            writer->addStringElement(writer, FTCrashField_Class, className);
            return true;
        case FTCrashObjCTypeUnknown:
            break;
        default:
            return false;
    }
#endif

    return false;
}

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const FTCrashReportWriter *const writer, const char *const key, const uintptr_t address,
                                int *limit)
{
    (*limit)--;
    const void *object = (const void *)address;
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, FTCrashField_Address, address);
        if (!writeObjCObject(writer, address, limit)) {
            if (object == NULL) {
                writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_NullPointer);
            } else if (isValidString(object)) {
                writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_String);
                writer->addStringElement(writer, FTCrashField_Value, (const char *)object);
            } else {
                writer->addStringElement(writer, FTCrashField_Type, FTCrashMemType_Unknown);
            }
        }
    }
    writer->endContainer(writer);
}

static bool isValidPointer(const uintptr_t address)
{
    if (address == (uintptr_t)NULL) {
        return false;
    }

    if (ftcrashobjc_isTaggedPointer((const void *)address)) {
        if (!ftcrashobjc_isValidTaggedPointer((const void *)address)) {
            return false;
        }
    }

    return true;
}

static bool isNotableAddress(const uintptr_t address)
{
    if (!isValidPointer(address)) {
        return false;
    }

    const void *object = (const void *)address;


    if (ftcrashobjc_objectType(object) != FTCrashObjCTypeUnknown) {
        return true;
    }

    if (isValidString(object)) {
        return true;
    }

    return false;
}

/** Write the contents of a memory location only if it contains notable data.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 */
static void writeMemoryContentsIfNotable(const FTCrashReportWriter *const writer, const char *const key,
                                         const uintptr_t address)
{
    if (isNotableAddress(address)) {
        int limit = kDefaultMemorySearchDepth;
        writeMemoryContents(writer, key, address, &limit);
    }
}

/** Look for a hex value in a string and try to write whatever it references.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param string The string to search.
 */
static void writeAddressReferencedByString(const FTCrashReportWriter *const writer, const char *const key,
                                           const char *string)
{
    uint64_t address = 0;
    if (string == NULL || !ftcrashstring_extractHexValue(string, (int)strlen(string), &address)) {
        return;
    }

    int limit = kDefaultMemorySearchDepth;
    writeMemoryContents(writer, key, (uintptr_t)address, &limit);
}

#pragma mark Backtrace

/** Write a backtrace to the report.
 *
 * @param writer The writer to write the backtrace to.
 *
 * @param key The object key, if needed.
 *
 * @param stackCursor The stack cursor to read from.
 */
static void writeBacktrace(const FTCrashReportWriter *const writer, const char *const key, FTCrashStackCursor *stackCursor)
{
    writer->beginObject(writer, key);
    {
        writer->beginArray(writer, FTCrashField_Contents);
        {
            while (stackCursor->advanceCursor(stackCursor)) {
                writer->beginObject(writer, NULL);
                {
                    if (stackCursor->symbolicate(stackCursor)) {
                        if (stackCursor->stackEntry.imageName != NULL) {
                            writer->addStringElement(writer, FTCrashField_ObjectName,
                                                     ftcrashfu_lastPathEntry(stackCursor->stackEntry.imageName));
                        }
                        writer->addUIntegerElement(writer, FTCrashField_ObjectAddr,
                                                   stackCursor->stackEntry.imageAddress);
                        if (stackCursor->stackEntry.symbolName != NULL) {
                            writer->addStringElement(writer, FTCrashField_SymbolName,
                                                     stackCursor->stackEntry.symbolName);
                        }
                        writer->addUIntegerElement(writer, FTCrashField_SymbolAddr,
                                                   stackCursor->stackEntry.symbolAddress);
                    }
                    writer->addUIntegerElement(writer, FTCrashField_InstructionAddr, stackCursor->stackEntry.address);
                }
                writer->endContainer(writer);
            }
        }
        writer->endContainer(writer);
        writer->addIntegerElement(writer, FTCrashField_Skipped, 0);
    }
    writer->endContainer(writer);
}

#pragma mark Stack

/** Write a dump of the stack contents to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param isStackOverflow If true, the stack has overflowed.
 */
static void writeStackContents(const FTCrashReportWriter *const writer, const char *const key,
                               const struct FTCrashMachineContext *const machineContext, const bool isStackOverflow)
{
    uintptr_t sp = ftcrashcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress =
        sp + (uintptr_t)(kStackContentsPushedDistance * (int)sizeof(sp) * ftcrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress =
        sp + (uintptr_t)(kStackContentsPoppedDistance * (int)sizeof(sp) * ftcrashcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, FTCrashField_GrowDirection, ftcrashcpu_stackGrowDirection() > 0 ? "+" : "-");
        writer->addUIntegerElement(writer, FTCrashField_DumpStart, lowAddress);
        writer->addUIntegerElement(writer, FTCrashField_DumpEnd, highAddress);
        writer->addUIntegerElement(writer, FTCrashField_StackPtr, sp);
        writer->addBooleanElement(writer, FTCrashField_Overflow, isStackOverflow);
        uint8_t stackBuffer[kStackContentsTotalDistance * sizeof(sp)];
        int copyLength = (int)(highAddress - lowAddress);
        if (ftcrashmem_copySafely((void *)lowAddress, stackBuffer, copyLength)) {
            writer->addDataElement(writer, FTCrashField_Contents, (void *)stackBuffer, copyLength);
        } else {
            writer->addStringElement(writer, FTCrashField_Error, "Stack contents not accessible");
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses near the stack pointer (above and below).
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param backDistance The distance towards the beginning of the stack to check.
 *
 * @param forwardDistance The distance past the end of the stack to check.
 */
static void writeNotableStackContents(const FTCrashReportWriter *const writer,
                                      const struct FTCrashMachineContext *const machineContext, const int backDistance,
                                      const int forwardDistance)
{
    uintptr_t sp = ftcrashcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress = sp + (uintptr_t)(backDistance * (int)sizeof(sp) * ftcrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress = sp + (uintptr_t)(forwardDistance * (int)sizeof(sp) * ftcrashcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    uintptr_t contentsAsPointer;
    char nameBuffer[40];
    for (uintptr_t address = lowAddress; address < highAddress; address += sizeof(address)) {
        if (ftcrashmem_copySafely((void *)address, &contentsAsPointer, sizeof(contentsAsPointer))) {
            snprintf(nameBuffer, sizeof(nameBuffer), "stack@%p", (void *)address);
            writeMemoryContentsIfNotable(writer, nameBuffer, contentsAsPointer);
        }
    }
}

#pragma mark Registers

/** Write the contents of all regular registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeBasicRegisters(const FTCrashReportWriter *const writer, const char *const key,
                                const struct FTCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = ftcrashcpu_numRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = ftcrashcpu_registerName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer, registerName, ftcrashcpu_registerValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write the contents of all exception registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeExceptionRegisters(const FTCrashReportWriter *const writer, const char *const key,
                                    const struct FTCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = ftcrashcpu_numExceptionRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = ftcrashcpu_exceptionRegisterName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer, registerName, ftcrashcpu_exceptionRegisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write all applicable registers.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeRegisters(const FTCrashReportWriter *const writer, const char *const key,
                           const struct FTCrashMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeBasicRegisters(writer, FTCrashField_Basic, machineContext);
        if (ftcrashmc_hasValidExceptionRegisters(machineContext)) {
            writeExceptionRegisters(writer, FTCrashField_Exception, machineContext);
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses contained in the CPU registers.
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableRegisters(const FTCrashReportWriter *const writer,
                                  const struct FTCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    const int numRegisters = ftcrashcpu_numRegisters();
    for (int reg = 0; reg < numRegisters; reg++) {
        registerName = ftcrashcpu_registerName(reg);
        if (registerName == NULL) {
            snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
            registerName = registerNameBuff;
        }
        writeMemoryContentsIfNotable(writer, registerName, (uintptr_t)ftcrashcpu_registerValue(machineContext, reg));
    }
}

#pragma mark Thread-specific

/** Write any notable addresses in the stack or registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableAddresses(const FTCrashReportWriter *const writer, const char *const key,
                                  const struct FTCrashMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeNotableRegisters(writer, machineContext);
        writeNotableStackContents(writer, machineContext, kStackNotableSearchBackDistance,
                                  kStackNotableSearchForwardDistance);
    }
    writer->endContainer(writer);
}

/** Write information about a thread to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The context whose thread to write about.
 *
 * @param threadIndex The index of the thread.
 *
 * @param shouldWriteNotableAddresses If true, write any notable addresses found.
 *
 * @param threadState The state code of the thread.
 */
static void writeThread(const FTCrashReportWriter *const writer, const char *const key,
                        const FTCrash_MonitorContext *const crash, const struct FTCrashMachineContext *const machineContext,
                        const int threadIndex, const bool shouldWriteNotableAddresses, const int threadState)
{
    bool isCrashedThread = ftcrashmc_isCrashedContext(machineContext);
    FTCrashThread thread = ftcrashmc_getThreadFromContext(machineContext);
    FTLOG_DEBUG("Writing thread %x (index %d). is crashed: %d", thread, threadIndex, isCrashedThread);

    FTCrashStackCursor stackCursor;
    bool hasBacktrace = getStackCursor(crash, machineContext, &stackCursor);
    const char *state = ftcrashthread_state_name(threadState);

    writer->beginObject(writer, key);
    {
        if (hasBacktrace) {
            writeBacktrace(writer, FTCrashField_Backtrace, &stackCursor);
        }
        if (ftcrashmc_canHaveCPUState(machineContext)) {
            writeRegisters(writer, FTCrashField_Registers, machineContext);
        }
        writer->addIntegerElement(writer, FTCrashField_Index, threadIndex);
        const char *name = ftcrashtc_getThreadName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, FTCrashField_Name, name);
        }
        name = ftcrashtc_getQueueName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, FTCrashField_DispatchQueue, name);
        }
        if (state != NULL) {
            writer->addStringElement(writer, FTCrashField_State, state);
        }
        writer->addBooleanElement(writer, FTCrashField_Crashed, isCrashedThread);
        writer->addBooleanElement(writer, FTCrashField_CurrentThread, thread == ftcrashthread_self());
        if (isCrashedThread) {
            writeStackContents(writer, FTCrashField_Stack, machineContext, stackCursor.state.hasGivenUp);
            if (shouldWriteNotableAddresses) {
                writeNotableAddresses(writer, FTCrashField_NotableAddresses, machineContext);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about all threads to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeThreads(const FTCrashReportWriter *const writer, const char *const key,
                         const FTCrash_MonitorContext *const crash, bool writeNotableAddresses)
{
    const struct FTCrashMachineContext *const context = crash->offendingMachineContext;
    FTCrashThread offendingThread = ftcrashmc_getThreadFromContext(context);
    int threadCount = ftcrashmc_getThreadCount(context);
    FTCrashMachineContext machineContext = { 0 };
    bool shouldRecordAllThreads = crash->requirements.shouldRecordAllThreads;

    // Fetch info for all threads.
    writer->beginArray(writer, key);
    {
        FTLOG_DEBUG("Writing %d of %d threads.", shouldRecordAllThreads ? threadCount : 1, threadCount);
        for (int i = 0; i < threadCount; i++) {
            FTCrashThread thread = ftcrashmc_getThreadAtIndex(context, i);
            int threadRunState = ftcrashthread_getThreadState(thread);
            if (thread == offendingThread) {
                writeThread(writer, NULL, crash, context, i, writeNotableAddresses, threadRunState);
            } else if (shouldRecordAllThreads) {
                ftcrashmc_getContextForThread(thread, &machineContext, false);
                writeThread(writer, NULL, crash, &machineContext, i, writeNotableAddresses, threadRunState);
            }
        }
    }
    writer->endContainer(writer);
}

#pragma mark Global Report Data

/** Write information about a binary image to the report.
 *
 * @param writer The writer.
 *
 * @param image The image to write.
 */
static void writeBinaryImage(const FTCrashReportWriter *const writer, const FTCrashBinaryImage *const image)
{
    writer->beginObject(writer, NULL);
    {
        writer->addUIntegerElement(writer, FTCrashField_ImageAddress, image->address);
        writer->addUIntegerElement(writer, FTCrashField_ImageVmAddress, image->vmAddress);
        writer->addUIntegerElement(writer, FTCrashField_ImageSize, image->size);
        writer->addStringElement(writer, FTCrashField_Name, image->name);
        writer->addUUIDElement(writer, FTCrashField_UUID, image->uuid);
        writer->addIntegerElement(writer, FTCrashField_CPUType, image->cpuType);
        writer->addIntegerElement(writer, FTCrashField_CPUSubType, image->cpuSubType);
        writer->addUIntegerElement(writer, FTCrashField_ImageMajorVersion, image->majorVersion);
        writer->addUIntegerElement(writer, FTCrashField_ImageMinorVersion, image->minorVersion);
        writer->addUIntegerElement(writer, FTCrashField_ImageRevisionVersion, image->revisionVersion);
        if (image->crashInfoMessage != NULL) {
            writer->addStringElement(writer, FTCrashField_ImageCrashInfoMessage, image->crashInfoMessage);
        }
        if (image->crashInfoMessage2 != NULL) {
            writer->addStringElement(writer, FTCrashField_ImageCrashInfoMessage2, image->crashInfoMessage2);
        }
        if (image->crashInfoBacktrace != NULL) {
            writer->addStringElement(writer, FTCrashField_ImageCrashInfoBacktrace, image->crashInfoBacktrace);
        }
        if (image->crashInfoSignature != NULL) {
            writer->addStringElement(writer, FTCrashField_ImageCrashInfoSignature, image->crashInfoSignature);
        }
    }
    writer->endContainer(writer);
}

/** Write information about all images to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeBinaryImages(const FTCrashReportWriter *const writer, const char *const key)
{
    uint32_t count = 0;
    const ftcrash_dyld_image_info *images = ftcrashbic_getImages(&count);

    writer->beginArray(writer, key);
    {
        for (uint32_t iImg = 0; iImg < count; iImg++) {
            ftcrash_dyld_image_info info = images[iImg];
            FTCrashBinaryImage image = { 0 };
            if (ftcrashdl_binaryImageForHeader(info.imageLoadAddress, info.imageFilePath, &image)) {
                writeBinaryImage(writer, &image);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about system memory to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeMemoryInfo(const FTCrashReportWriter *const writer, const char *const key,
                            const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, FTCrashField_Size, monitorContext->System.memorySize);
        writer->addUIntegerElement(writer, FTCrashField_Usable, monitorContext->System.usableMemory);
        writer->addUIntegerElement(writer, FTCrashField_Free, monitorContext->System.freeMemory);
    }
    writer->endContainer(writer);
}

static inline bool isCrashOfMonitorType(const FTCrash_MonitorContext *const crash, const FTCrashMonitorAPI *monitorAPI)
{
    return ftcrashstring_safeStrcmp(crash->monitorId, monitorAPI->monitorId()) == 0;
}

/** Write information about the error leading to the crash to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeError(const FTCrashReportWriter *const writer, const char *const key,
                       const FTCrash_MonitorContext *const crash)
{
    writer->beginObject(writer, key);
    {
#if FT_HOST_APPLE
        writer->beginObject(writer, FTCrashField_Mach);
        {
            const char *machExceptionName = ftcrashmach_exceptionName(crash->mach.type);
            const char *machCodeName = crash->mach.code == 0 ? NULL : ftcrashmach_kernelReturnCodeName(crash->mach.code);
            writer->addUIntegerElement(writer, FTCrashField_Exception, (unsigned)crash->mach.type);
            if (machExceptionName != NULL) {
                writer->addStringElement(writer, FTCrashField_ExceptionName, machExceptionName);
            }
            writer->addUIntegerElement(writer, FTCrashField_Code, (unsigned)crash->mach.code);
            if (machCodeName != NULL) {
                writer->addStringElement(writer, FTCrashField_CodeName, machCodeName);
            }
            writer->addUIntegerElement(writer, FTCrashField_Subcode, (size_t)crash->mach.subcode);
        }
        writer->endContainer(writer);
#endif
        writer->beginObject(writer, FTCrashField_Signal);
        {
            const char *sigName = ftcrashsignal_signalName(crash->signal.signum);
            const char *sigCodeName = ftcrashsignal_signalCodeName(crash->signal.signum, crash->signal.sigcode);
            writer->addUIntegerElement(writer, FTCrashField_Signal, (unsigned)crash->signal.signum);
            if (sigName != NULL) {
                writer->addStringElement(writer, FTCrashField_Name, sigName);
            }
            writer->addUIntegerElement(writer, FTCrashField_Code, (unsigned)crash->signal.sigcode);
            if (sigCodeName != NULL) {
                writer->addStringElement(writer, FTCrashField_CodeName, sigCodeName);
            }
        }
        writer->endContainer(writer);

        writer->addUIntegerElement(writer, FTCrashField_Address, crash->faultAddress);
        if (crash->crashReason != NULL) {
            writer->addStringElement(writer, FTCrashField_Reason, crash->crashReason);
        }

        if (isCrashOfMonitorType(crash, ftcrashcm_nsexception_getAPI())) {
            writer->addStringElement(writer, FTCrashField_Type, FTCrashExcType_NSException);
            writer->beginObject(writer, FTCrashField_NSException);
            {
                writer->addStringElement(writer, FTCrashField_Name, crash->NSException.name);
                writer->addStringElement(writer, FTCrashField_UserInfo, crash->NSException.userInfo);
                writeAddressReferencedByString(writer, FTCrashField_ReferencedObject, crash->crashReason);
            }
            writer->endContainer(writer);
        } else if (isCrashOfMonitorType(crash, ftcrashcm_machexception_getAPI())) {
            writer->addStringElement(writer, FTCrashField_Type, FTCrashExcType_Mach);
        } else if (isCrashOfMonitorType(crash, ftcrashcm_signal_getAPI())) {
            writer->addStringElement(writer, FTCrashField_Type, FTCrashExcType_Signal);
        } else if (isCrashOfMonitorType(crash, ftcrashcm_cppexception_getAPI())) {
            writer->addStringElement(writer, FTCrashField_Type, FTCrashExcType_CPPException);
            writer->beginObject(writer, FTCrashField_CPPException);
            {
                writer->addStringElement(writer, FTCrashField_Name, crash->CPPException.name);
            }
            writer->endContainer(writer);
        }else if (isCrashOfMonitorType(crash, ftcrashcm_system_getAPI()) ||
                   isCrashOfMonitorType(crash, ftcrashcm_appstate_getAPI())) {
            FTLOG_ERROR("Crash monitor type %s shouldn't be able to cause events!", crash->monitorId);
        } else {
            FTLOG_WARN("Unknown crash monitor type: %s", crash->monitorId);
        }
    }
    writer->endContainer(writer);
}

/** Write information about app runtime, etc to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param monitorContext The event monitor context.
 */
static void writeAppStats(const FTCrashReportWriter *const writer, const char *const key,
                          const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(writer, FTCrashField_AppActive, monitorContext->AppState.applicationIsActive);
        writer->addBooleanElement(writer, FTCrashField_AppInFG, monitorContext->AppState.applicationIsInForeground);

        writer->addIntegerElement(writer, FTCrashField_LaunchesSinceCrash,
                                  monitorContext->AppState.launchesSinceLastCrash);
        writer->addIntegerElement(writer, FTCrashField_SessionsSinceCrash,
                                  monitorContext->AppState.sessionsSinceLastCrash);
        writer->addFloatingPointElement(writer, FTCrashField_ActiveTimeSinceCrash,
                                        monitorContext->AppState.activeDurationSinceLastCrash);
        writer->addFloatingPointElement(writer, FTCrashField_BGTimeSinceCrash,
                                        monitorContext->AppState.backgroundDurationSinceLastCrash);

        writer->addIntegerElement(writer, FTCrashField_SessionsSinceLaunch,
                                  monitorContext->AppState.sessionsSinceLaunch);
        writer->addFloatingPointElement(writer, FTCrashField_ActiveTimeSinceLaunch,
                                        monitorContext->AppState.activeDurationSinceLaunch);
        writer->addFloatingPointElement(writer, FTCrashField_BGTimeSinceLaunch,
                                        monitorContext->AppState.backgroundDurationSinceLaunch);
    }
    writer->endContainer(writer);
}

/** Write information about this process.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeProcessState(const FTCrashReportWriter *const writer, const char *const key,
                              const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if (monitorContext->ZombieException.address != 0) {
            writer->beginObject(writer, FTCrashField_LastDeallocedNSException);
            {
                writer->addUIntegerElement(writer, FTCrashField_Address, monitorContext->ZombieException.address);
                writer->addStringElement(writer, FTCrashField_Name, monitorContext->ZombieException.name);
                writer->addStringElement(writer, FTCrashField_Reason, monitorContext->ZombieException.reason);
                writeAddressReferencedByString(writer, FTCrashField_ReferencedObject,
                                               monitorContext->ZombieException.reason);
            }
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);
}

/** Write basic report information.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param type The report type.
 *
 * @param reportID The report ID.
 */
static void writeReportInfo(const FTCrashReportWriter *const writer, const char *const key, const char *const type,
                            const char *const reportID, const char *const processName)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, FTCrashField_Version, FTCRASH_REPORT_VERSION);
        writer->addStringElement(writer, FTCrashField_ID, reportID);
        writer->addStringElement(writer, FTCrashField_ProcessName, processName);
        writer->addUIntegerElement(writer, FTCrashField_Timestamp, ftcrashdate_microseconds());
        writer->addStringElement(writer, FTCrashField_Type, type);
    }
    writer->endContainer(writer);
}

static void writeRecrash(const FTCrashReportWriter *const writer, const char *const key, const char *crashReportPath)
{
    writer->addJSONFileElement(writer, key, crashReportPath, true);
}

#pragma mark Setup

/** Prepare a report writer for use.
 *
 * @param writer The writer to prepare.
 *
 * @param context JSON writer contextual information.
 */
static void prepareReportWriter(FTCrashReportWriter *const writer, FTCrashJSONEncodeContext *const context)
{
    writer->addBooleanElement = addBooleanElement;
    writer->addFloatingPointElement = addFloatingPointElement;
    writer->addIntegerElement = addIntegerElement;
    writer->addUIntegerElement = addUIntegerElement;
    writer->addStringElement = addStringElement;
    writer->addTextFileElement = addTextFileElement;
    writer->addTextFileLinesElement = addTextLinesFromFile;
    writer->addJSONFileElement = addJSONElementFromFile;
    writer->addDataElement = addDataElement;
    writer->beginDataElement = beginDataElement;
    writer->appendDataElement = appendDataElement;
    writer->endDataElement = endDataElement;
    writer->addUUIDElement = addUUIDElement;
    writer->addJSONElement = addJSONElement;
    writer->beginObject = beginObject;
    writer->beginArray = beginArray;
    writer->endContainer = endContainer;
    writer->context = context;
}

// ============================================================================
#pragma mark - Main API -
// ============================================================================

void ftcrashreport_writeRecrashReport(const FTCrash_MonitorContext *const monitorContext, const char *const path)
{
    char writeBuffer[1024];
    FTCrashBufferedWriter bufferedWriter;
    static char tempPath[FTCRASHFU_MAX_PATH_LENGTH];
    strncpy(tempPath, path, sizeof(tempPath) - 10);
    strncpy(tempPath + strlen(tempPath) - 5, ".old", 5);
    FTLOG_INFO("Writing recrash report to %s", path);

    if (rename(path, tempPath) < 0) {
        FTLOG_ERROR("Could not rename %s to %s: %s", path, tempPath, strerror(errno));
    }
    if (!ftcrashfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    ftcrashtc_freeze();

    FTCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    FTCrashReportWriter concreteWriter;
    FTCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    ftcrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, FTCrashField_Report);
    {
        writeRecrash(writer, FTCrashField_RecrashReport, tempPath);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);
        if (remove(tempPath) < 0) {
            FTLOG_ERROR("Could not remove %s: %s", tempPath, strerror(errno));
        }
        writeReportInfo(writer, FTCrashField_Report, FTCrashReportType_Minimal, monitorContext->eventID,
                        monitorContext->System.processName);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, FTCrashField_Crash);
        {
            writeError(writer, FTCrashField_Error, monitorContext);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
            FTCrashThread thread = ftcrashmc_getThreadFromContext(monitorContext->offendingMachineContext);
            int threadIndex = ftcrashmc_indexOfThread(monitorContext->offendingMachineContext, thread);
            int threadRunState = ftcrashthread_getThreadState(thread);
            writeThread(writer, FTCrashField_CrashedThread, monitorContext, monitorContext->offendingMachineContext,
                        threadIndex, false, threadRunState);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);

        if (g_userSectionWriteCallback != NULL) {
            writer->beginObject(writer, FTCrashField_User);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
            FTCrash_ExceptionHandlingPlan plan = ftcrashexc_monitorContextToPlan(monitorContext);
            g_userSectionWriteCallback(&plan, writer);
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);

    ftcrashjson_endEncode(getJsonContext(writer));
    ftcrashfu_closeBufferedWriter(&bufferedWriter);
    ftcrashtc_unfreeze();
}

static void writeAppMemoryInfo(const FTCrashReportWriter *const writer, const char *const key,
                               const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, FTCrashField_MemoryFootprint, monitorContext->AppMemory.footprint);
        writer->addUIntegerElement(writer, FTCrashField_MemoryRemaining, monitorContext->AppMemory.remaining);
        writer->addStringElement(writer, FTCrashField_MemoryPressure, monitorContext->AppMemory.pressure);
        writer->addStringElement(writer, FTCrashField_MemoryLevel, monitorContext->AppMemory.level);
        writer->addUIntegerElement(writer, FTCrashField_MemoryLimit, monitorContext->AppMemory.limit);
        writer->addStringElement(writer, FTCrashField_AppTransitionState, monitorContext->AppMemory.state);
    }
    writer->endContainer(writer);
}

static void writeSystemInfo(const FTCrashReportWriter *const writer, const char *const key,
                            const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, FTCrashField_SystemName, monitorContext->System.systemName);
        writer->addStringElement(writer, FTCrashField_SystemVersion, monitorContext->System.systemVersion);
        writer->addStringElement(writer, FTCrashField_Machine, monitorContext->System.machine);
        writer->addStringElement(writer, FTCrashField_Model, monitorContext->System.model);
        writer->addStringElement(writer, FTCrashField_KernelVersion, monitorContext->System.kernelVersion);
        writer->addStringElement(writer, FTCrashField_OSVersion, monitorContext->System.osVersion);
        writer->addBooleanElement(writer, FTCrashField_Jailbroken, monitorContext->System.isJailbroken);
        writer->addBooleanElement(writer, FTCrashField_ProcTranslated, monitorContext->System.procTranslated);
        writer->addStringElement(writer, FTCrashField_BootTime, monitorContext->System.bootTime);
        writer->addStringElement(writer, FTCrashField_AppStartTime, monitorContext->System.appStartTime);
        writer->addStringElement(writer, FTCrashField_ExecutablePath, monitorContext->System.executablePath);
        writer->addStringElement(writer, FTCrashField_Executable, monitorContext->System.executableName);
        writer->addStringElement(writer, FTCrashField_BundleID, monitorContext->System.bundleID);
        writer->addStringElement(writer, FTCrashField_BundleName, monitorContext->System.bundleName);
        writer->addStringElement(writer, FTCrashField_BundleVersion, monitorContext->System.bundleVersion);
        writer->addStringElement(writer, FTCrashField_BundleShortVersion, monitorContext->System.bundleShortVersion);
        writer->addStringElement(writer, FTCrashField_AppUUID, monitorContext->System.appID);
        writer->addStringElement(writer, FTCrashField_CPUArch, monitorContext->System.cpuArchitecture);
        writer->addStringElement(writer, FTCrashField_BinaryArch, monitorContext->System.binaryArchitecture);
        writer->addIntegerElement(writer, FTCrashField_CPUType, monitorContext->System.cpuType);
        writer->addStringElement(writer, FTCrashField_ClangVersion, monitorContext->System.clangVersion);
        writer->addIntegerElement(writer, FTCrashField_CPUSubType, monitorContext->System.cpuSubType);
        writer->addIntegerElement(writer, FTCrashField_BinaryCPUType, monitorContext->System.binaryCPUType);
        writer->addIntegerElement(writer, FTCrashField_BinaryCPUSubType, monitorContext->System.binaryCPUSubType);
        writer->addStringElement(writer, FTCrashField_TimeZone, monitorContext->System.timezone);
        writer->addStringElement(writer, FTCrashField_ProcessName, monitorContext->System.processName);
        writer->addIntegerElement(writer, FTCrashField_ProcessID, monitorContext->System.processID);
        writer->addIntegerElement(writer, FTCrashField_ParentProcessID, monitorContext->System.parentProcessID);
        writer->addStringElement(writer, FTCrashField_DeviceAppHash, monitorContext->System.deviceAppHash);
        writer->addStringElement(writer, FTCrashField_BuildType, monitorContext->System.buildType);
        writer->addIntegerElement(writer, FTCrashField_Storage, (int64_t)monitorContext->System.storageSize);
        writer->addIntegerElement(writer, FTCrashField_FreeStorage, (int64_t)monitorContext->System.freeStorageSize);

        writeMemoryInfo(writer, FTCrashField_Memory, monitorContext);
        writeAppStats(writer, FTCrashField_AppStats, monitorContext);
        writeAppMemoryInfo(writer, FTCrashField_AppMemory, monitorContext);
    }
    writer->endContainer(writer);
}

static void writeDebugInfo(const FTCrashReportWriter *const writer, const char *const key,
                           const FTCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if (monitorContext->consoleLogPath != NULL) {
            addTextLinesFromFile(writer, FTCrashField_ConsoleLog, monitorContext->consoleLogPath);
        }
    }
    writer->endContainer(writer);
}

void ftcrashreport_writeStandardReport(FTCrash_MonitorContext *const monitorContext, const char *const path)
{
    FTLOG_INFO("Writing crash report to %s", path);
    char writeBuffer[1024];
    FTCrashBufferedWriter bufferedWriter;

    if (!ftcrashfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    ftcrashtc_freeze();

    FTCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    FTCrashReportWriter concreteWriter;
    FTCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    ftcrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, FTCrashField_Report);
    {
        writeReportInfo(writer, FTCrashField_Report, FTCrashReportType_Standard, monitorContext->eventID,
                        monitorContext->System.processName);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);

        if (!monitorContext->omitBinaryImages) {
            writeBinaryImages(writer, FTCrashField_BinaryImages);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
        }

        writeProcessState(writer, FTCrashField_ProcessState, monitorContext);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);

        writeSystemInfo(writer, FTCrashField_System, monitorContext);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, FTCrashField_Crash);
        {
            writeError(writer, FTCrashField_Error, monitorContext);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
            writeThreads(writer, FTCrashField_Threads, monitorContext, g_introspectionRules.enabled);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
            if (monitorContext->suspendedThreadsCount > 0) {
                // Special case: If we only needed to suspend the environment to record the threads, then we can
                // safely resume now. This gives any remaining callbacks more freedom.
                monitorContext->requirements.asyncSafetyBecauseThreadsSuspended = false;
                if (!ftcrashcexc_requiresAsyncSafety(monitorContext->requirements)) {
                    ftcrashmc_resumeEnvironment(&monitorContext->suspendedThreads, &monitorContext->suspendedThreadsCount);
                }
            }
        }
        writer->endContainer(writer);

        if (g_userInfoJSON != NULL) {
            addJSONElement(writer, FTCrashField_User, g_userInfoJSON, false);
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
        } else {
            writer->beginObject(writer, FTCrashField_User);
        }
        if (g_userSectionWriteCallback != NULL) {
            ftcrashfu_flushBufferedWriter(&bufferedWriter);
            FTCrash_ExceptionHandlingPlan plan = ftcrashexc_monitorContextToPlan(monitorContext);
            g_userSectionWriteCallback(&plan, writer);
        }
        writer->endContainer(writer);
        ftcrashfu_flushBufferedWriter(&bufferedWriter);

        writeDebugInfo(writer, FTCrashField_Debug, monitorContext);
    }
    writer->endContainer(writer);

    ftcrashjson_endEncode(getJsonContext(writer));
    ftcrashfu_closeBufferedWriter(&bufferedWriter);
    ftcrashtc_unfreeze();
}

void ftcrashreport_setUserInfoJSON(const char *const userInfoJSON)
{
    pthread_mutex_lock(&g_userInfoMutex);
    if (g_userInfoJSON != NULL) {
        free((void *)g_userInfoJSON);
    }
    if (userInfoJSON == NULL) {
        g_userInfoJSON = NULL;
    } else {
        g_userInfoJSON = strdup(userInfoJSON);
    }
    pthread_mutex_unlock(&g_userInfoMutex);
}

const char *ftcrashreport_getUserInfoJSON(void)
{
    const char *userInfoJSONCopy = NULL;

    pthread_mutex_lock(&g_userInfoMutex);
    if (g_userInfoJSON != NULL) {
        userInfoJSONCopy = strdup(g_userInfoJSON);
    }
    pthread_mutex_unlock(&g_userInfoMutex);

    return userInfoJSONCopy;
}

void ftcrashreport_setIntrospectMemory(bool shouldIntrospectMemory)
{
    g_introspectionRules.enabled = shouldIntrospectMemory;
}

void ftcrashreport_setDoNotIntrospectClasses(const char **doNotIntrospectClasses, int length)
{
    const char **oldClasses = g_introspectionRules.restrictedClasses;
    int oldClassesLength = g_introspectionRules.restrictedClassesCount;
    const char **newClasses = NULL;
    int newClassesLength = 0;

    if (doNotIntrospectClasses != NULL && length > 0) {
        newClassesLength = length;
        newClasses = malloc(sizeof(*newClasses) * (unsigned)newClassesLength);
        if (newClasses == NULL) {
            FTLOG_ERROR("Could not allocate memory");
            return;
        }

        for (int i = 0; i < newClassesLength; i++) {
            newClasses[i] = strdup(doNotIntrospectClasses[i]);
        }
    }

    g_introspectionRules.restrictedClasses = newClasses;
    g_introspectionRules.restrictedClassesCount = newClassesLength;

    if (oldClasses != NULL) {
        for (int i = 0; i < oldClassesLength; i++) {
            free((void *)oldClasses[i]);
        }
        free(oldClasses);
    }
}

void ftcrashreport_setIsWritingReportCallback(const FTCrashIsWritingReportCallback isWritingReportCallback)
{
    g_userSectionWriteCallback = isWritingReportCallback;
}
