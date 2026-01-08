//
//  FTCrashReportFields.h
//
//  Created by Karl Stenerud on 2012-10-07.
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

#ifndef FTCrashReportFields_h
#define FTCrashReportFields_h

#ifdef __OBJC__
#include <Foundation/Foundation.h>
typedef NSString *FTCrashReportField;
#define FTCrashCRF_CONVERT_STRING(str) @str
#else /* __OBJC__ */
typedef const char *FTCrashReportField;
#define FTCrashCRF_CONVERT_STRING(str) str
#endif /* __OBJC__ */

#ifndef NS_TYPED_ENUM
#define NS_TYPED_ENUM
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(_name)
#endif

#define FTCrashCRF_DEFINE_CONSTANT(type, name, swift_name, string) \
    static type const type##_##name NS_SWIFT_NAME(swift_name) = FTCrashCRF_CONVERT_STRING(string);

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - Report Types -

typedef FTCrashReportField FTCrashReportType NS_TYPED_ENUM NS_SWIFT_NAME(ReportType);

FTCrashCRF_DEFINE_CONSTANT(FTCrashReportType, Minimal, minimal, "minimal")
FTCrashCRF_DEFINE_CONSTANT(FTCrashReportType, Standard, standard, "standard")
FTCrashCRF_DEFINE_CONSTANT(FTCrashReportType, Custom, custom, "custom")

#pragma mark - Memory Types -

typedef FTCrashReportField FTCrashMemType NS_TYPED_ENUM NS_SWIFT_NAME(MemoryType);

FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, Block, block, "objc_block")
FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, Class, class, "objc_class")
FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, NullPointer, nullPointer, "null_pointer")
FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, Object, object, "objc_object")
FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, String, string, "string")
FTCrashCRF_DEFINE_CONSTANT(FTCrashMemType, Unknown, unknown, "unknown")

#pragma mark - Exception Types -

typedef FTCrashReportField FTCrashExcType NS_TYPED_ENUM NS_SWIFT_NAME(ExceptionType);

FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, CPPException, cppException, "cpp_exception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, Deadlock, deadlock, "deadlock")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, Mach, mach, "mach")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, NSException, nsException, "nsexception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, Signal, signal, "signal")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, User, user, "user")
FTCrashCRF_DEFINE_CONSTANT(FTCrashExcType, MemoryTermination, memoryTermination, "memory_termination")

#pragma mark - Common -

typedef FTCrashReportField FTCrashField NS_TYPED_ENUM NS_SWIFT_NAME(CrashField);

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Address, address, "address")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Contents, contents, "contents")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Exception, exception, "exception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, FirstObject, firstObject, "first_object")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Index, index, "index")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CPU, cpu, "cpu")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Ivars, ivars, "ivars")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Language, language, "language")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Name, name, "name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, UserInfo, userInfo, "userInfo")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ReferencedObject, referencedObject, "referenced_object")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Type, type, "type")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, UUID, uuid, "uuid")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Value, value, "value")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryLimit, memoryLimit, "memory_limit")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Error, error, "error")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, JSONData, jsonData, "json_data")

#pragma mark - Notable Address -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Class, class, "class")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, LastDeallocObject, lastDeallocObject, "last_deallocated_obj")

#pragma mark - Backtrace -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, InstructionAddr, instructionAddr, "instruction_addr")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, LineOfCode, lineOfCode, "line_of_code")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ObjectAddr, objectAddr, "object_addr")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ObjectName, objectName, "object_name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SymbolAddr, symbolAddr, "symbol_addr")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SymbolName, symbolName, "symbol_name")

#pragma mark - Stack Dump -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, DumpEnd, dumpEnd, "dump_end")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, DumpStart, dumpStart, "dump_start")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, GrowDirection, growDirection, "grow_direction")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Overflow, overflow, "overflow")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, StackPtr, stackPtr, "stack_pointer")

#pragma mark - Thread Dump -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Backtrace, backtrace, "backtrace")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Basic, basic, "basic")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Crashed, crashed, "crashed")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CurrentThread, currentThread, "current_thread")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, DispatchQueue, dispatchQueue, "dispatch_queue")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, NotableAddresses, notableAddresses, "notable_addresses")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Registers, registers, "registers")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Skipped, skipped, "skipped")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Stack, stack, "stack")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, State, state, "state")

#pragma mark - Binary Image -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CPUSubType, cpuSubType, "cpu_subtype")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CPUType, cpuType, "cpu_type")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageAddress, imageAddress, "image_addr")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageVmAddress, imageVmAddress, "image_vmaddr")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageSize, imageSize, "image_size")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageMajorVersion, imageMajorVersion, "major_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageMinorVersion, imageMinorVersion, "minor_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageRevisionVersion, imageRevisionVersion, "revision_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageCrashInfoMessage, imageCrashInfoMessage, "crash_info_message")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageCrashInfoMessage2, imageCrashInfoMessage2, "crash_info_message2")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageCrashInfoBacktrace, imageCrashInfoBacktrace, "crash_info_backtrace")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ImageCrashInfoSignature, imageCrashInfoSignature, "crash_info_signature")

#pragma mark - Memory -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Free, free, "free")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Usable, usable, "usable")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Available, available, "available")

#pragma mark - Error -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Code, code, "code")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CodeName, codeName, "code_name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CPPException, cppException, "cpp_exception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ExceptionName, exceptionName, "exception_name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Mach, mach, "mach")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, NSException, nsException, "nsexception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Reason, reason, "reason")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Signal, signal, "signal")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Subcode, subcode, "subcode")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, UserReported, userReported, "user_reported")

#pragma mark - Process State -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, LastDeallocedNSException, lastDeallocedNSException, "last_dealloced_nsexception")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ProcessState, processState, "process")

#pragma mark - App Stats -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ActiveTimeSinceCrash, activeTimeSinceCrash, "active_time_since_last_crash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ActiveTimeSinceLaunch, activeTimeSinceLaunch, "active_time_since_launch")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppActive, appActive, "application_active")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppInFG, appInFG, "application_in_foreground")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BGTimeSinceCrash, bgTimeSinceCrash, "background_time_since_last_crash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BGTimeSinceLaunch, bgTimeSinceLaunch, "background_time_since_launch")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, LaunchesSinceCrash, launchesSinceCrash, "launches_since_last_crash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SessionsSinceCrash, sessionsSinceCrash, "sessions_since_last_crash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SessionsSinceLaunch, sessionsSinceLaunch, "sessions_since_launch")

#pragma mark - Report -

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Crash, crash, "crash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Debug, debug, "debug")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Diagnosis, diagnosis, "diagnosis")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ID, id, "id")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ProcessName, processName, "process_name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Report, report, "report")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Timestamp, timestamp, "timestamp")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Version, version, "version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppMemory, appMemory, "app_memory")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryTermination, memoryTermination, "memory_termination")

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CrashedThread, crashedThread, "crashed_thread")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppStats, appStats, "application_stats")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BinaryImages, binaryImages, "binary_images")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, System, system, "system")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Memory, memory, "memory")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Threads, threads, "threads")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, User, user, "user")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ConsoleLog, consoleLog, "console_log")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Incomplete, incomplete, "incomplete")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, RecrashReport, recrashReport, "recrash_report")

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppStartTime, appStartTime, "app_start_time")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppUUID, appUUID, "app_uuid")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BootTime, bootTime, "boot_time")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BundleID, bundleID, "CFBundleIdentifier")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BundleName, bundleName, "CFBundleName")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BundleShortVersion, bundleShortVersion, "CFBundleShortVersionString")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BundleVersion, bundleVersion, "CFBundleVersion")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, CPUArch, cpuArch, "cpu_arch")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BinaryArch, binaryArch, "binary_arch")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ClangVersion, clangVersion, "clang_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BinaryCPUType, binaryCPUType, "binary_cpu_type")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BinaryCPUSubType, binaryCPUSubType, "binary_cpu_subtype")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, DeviceAppHash, deviceAppHash, "device_app_hash")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Executable, executable, "CFBundleExecutable")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ExecutablePath, executablePath, "CFBundleExecutablePath")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Jailbroken, jailbroken, "jailbroken")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ProcTranslated, procTranslated, "proc_translated")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, KernelVersion, kernelVersion, "kernel_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Machine, machine, "machine")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Model, model, "model")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, OSVersion, osVersion, "os_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ParentProcessID, parentProcessID, "parent_process_id")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, ProcessID, processID, "process_id")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Size, size, "size")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, Storage, storage, "storage")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, FreeStorage, freeStorage, "freeStorage")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SystemName, systemName, "system_name")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, SystemVersion, systemVersion, "system_version")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, TimeZone, timeZone, "time_zone")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, BuildType, buildType, "build_type")

FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryFootprint, memoryFootprint, "memory_footprint")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryRemaining, memoryRemaining, "memory_remaining")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryPressure, memoryPressure, "memory_pressure")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, MemoryLevel, memoryLevel, "memory_level")
FTCrashCRF_DEFINE_CONSTANT(FTCrashField, AppTransitionState, appTransitionState, "app_transition_state")

#ifdef __cplusplus
}
#endif
#endif /* FTCrashReportFields_h */
