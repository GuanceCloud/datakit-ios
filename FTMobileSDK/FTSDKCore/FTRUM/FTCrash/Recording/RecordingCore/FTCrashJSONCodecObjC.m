//
//  FTCrashJSONCodecObjC.m
//
//  Created by Karl Stenerud on 2012-01-08.
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

#import "FTCrashJSONCodecObjC.h"

#import "FTCrashDate.h"
#import "FTCrashJSONCodec.h"
#import "FTCrashNSErrorHelper.h"

@interface FTCrashJSONCodec ()

#pragma mark Properties

/** Callbacks from the C library */
@property(nonatomic, readwrite, assign) FTCrashJSONDecodeCallbacks *callbacks;

/** Stack of arrays/objects as the decoded content is built */
@property(nonatomic, readwrite, strong) NSMutableArray *containerStack;

/** Current array or object being decoded (weak ref) */
@property(nonatomic, readwrite, weak) id currentContainer;

/** Top level array or object in the decoded tree */
@property(nonatomic, readwrite, strong) id topLevelContainer;

/** Data that has been serialized into JSON form */
@property(nonatomic, readwrite, strong) NSMutableData *serializedData;

/** Any error that has occurred */
@property(nonatomic, readwrite, strong) NSError *error;

/** If true, pretty print while encoding */
@property(nonatomic, readwrite, assign) bool prettyPrint;

/** If true, sort object keys while encoding */
@property(nonatomic, readwrite, assign) bool sorted;

/** If true, don't store nulls in arrays */
@property(nonatomic, readwrite, assign) bool ignoreNullsInArrays;

/** If true, don't store nulls in objects */
@property(nonatomic, readwrite, assign) bool ignoreNullsInObjects;

#pragma mark Constructors

/** Convenience constructor.
 *
 * @param encodeOptions Optional behavior when encoding to JSON.
 *
 * @param decodeOptions Optional behavior when decoding from JSON.
 *
 * @return A new codec.
 */
+ (FTCrashJSONCodec *)codecWithEncodeOptions:(FTCrashJSONEncodeOption)encodeOptions
                          decodeOptions:(FTCrashJSONDecodeOption)decodeOptions;

/** Initializer.
 *
 * @param encodeOptions Optional behavior when encoding to JSON.
 *
 * @param decodeOptions Optional behavior when decoding from JSON.
 *
 * @return The initialized codec.
 */
- (id)initWithEncodeOptions:(FTCrashJSONEncodeOption)encodeOptions decodeOptions:(FTCrashJSONDecodeOption)decodeOptions;

@end

#pragma mark -
#pragma mark -

@implementation FTCrashJSONCodec

#pragma mark Constructors/Destructor

+ (FTCrashJSONCodec *)codecWithEncodeOptions:(FTCrashJSONEncodeOption)encodeOptions
                          decodeOptions:(FTCrashJSONDecodeOption)decodeOptions
{
    return [[self alloc] initWithEncodeOptions:encodeOptions decodeOptions:decodeOptions];
}

- (id)initWithEncodeOptions:(FTCrashJSONEncodeOption)encodeOptions decodeOptions:(FTCrashJSONDecodeOption)decodeOptions
{
    if ((self = [super init])) {
        _containerStack = [NSMutableArray array];
        _callbacks = malloc(sizeof(*self.callbacks));
        _callbacks->onBeginArray = onBeginArray;
        _callbacks->onBeginObject = onBeginObject;
        _callbacks->onBooleanElement = onBooleanElement;
        _callbacks->onEndContainer = onEndContainer;
        _callbacks->onEndData = onEndData;
        _callbacks->onFloatingPointElement = onFloatingPointElement;
        _callbacks->onIntegerElement = onIntegerElement;
        _callbacks->onUnsignedIntegerElement = onUnsignedIntegerElement;
        _callbacks->onNullElement = onNullElement;
        _callbacks->onStringElement = onStringElement;
        _prettyPrint = (encodeOptions & FTCrashJSONEncodeOptionPretty) != 0;
        _sorted = (encodeOptions & FTCrashJSONEncodeOptionSorted) != 0;
        _ignoreNullsInArrays = (decodeOptions & FTCrashJSONDecodeOptionIgnoreNullInArray) != 0;
        _ignoreNullsInObjects = (decodeOptions & FTCrashJSONDecodeOptionIgnoreNullInObject) != 0;
    }
    return self;
}

- (void)dealloc
{
    free(self.callbacks);
}

#pragma mark Utility

static inline NSString *stringFromCString(const char *const string)
{
    if (string == NULL) {
        return nil;
    }
    return [NSString stringWithCString:string encoding:NSUTF8StringEncoding];
}

#pragma mark Callbacks

static int onElement(FTCrashJSONCodec *codec, NSString *name, id element)
{
    id currentContainer = codec.currentContainer;
    if (currentContainer == nil) {
        codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                                  code:0
                                           description:@"Type %@ not allowed as top level container", [element class]];
        return FTCRASHJSON_ERROR_INVALID_DATA;
    }

    if ([currentContainer isKindOfClass:[NSMutableDictionary class]]) {
        [(NSMutableDictionary *)currentContainer setValue:element forKey:name];
    } else {
        [(NSMutableArray *)currentContainer addObject:element];
    }
    return FTCRASHJSON_OK;
}

static int onBeginContainer(FTCrashJSONCodec *codec, NSString *name, id container)
{
    if (codec.topLevelContainer == nil) {
        codec.topLevelContainer = container;
    } else {
        int result = onElement(codec, name, container);
        if (result != FTCRASHJSON_OK) {
            return result;
        }
    }
    codec.currentContainer = container;
    [codec.containerStack addObject:container];
    return FTCRASHJSON_OK;
}

static int onBooleanElement(const char *const cName, const bool value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithBool:value];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onFloatingPointElement(const char *const cName, const double value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithDouble:value];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onIntegerElement(const char *const cName, const int64_t value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithLongLong:value];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onUnsignedIntegerElement(const char *const cName, const uint64_t value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithUnsignedLongLong:value];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onNullElement(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;

    id currentContainer = codec.currentContainer;
    if ((codec.ignoreNullsInArrays && [currentContainer isKindOfClass:[NSArray class]]) ||
        (codec.ignoreNullsInObjects && [currentContainer isKindOfClass:[NSDictionary class]])) {
        return FTCRASHJSON_OK;
    }

    return onElement(codec, name, [NSNull null]);
}

static int onStringElement(const char *const cName, const char *const value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onBeginObject(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id container = [NSMutableDictionary dictionary];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onBeginContainer(codec, name, container);
}

static int onBeginArray(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id container = [NSMutableArray array];
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;
    return onBeginContainer(codec, name, container);
}

static int onEndContainer(void *const userData)
{
    FTCrashJSONCodec *codec = (__bridge FTCrashJSONCodec *)userData;

    if ([codec.containerStack count] == 0) {
        codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                                  code:0
                                           description:@"Already at the top level; no container left to end"];
        return FTCRASHJSON_ERROR_INVALID_DATA;
    }
    [codec.containerStack removeLastObject];
    NSUInteger count = [codec.containerStack count];
    if (count > 0) {
        codec.currentContainer = [codec.containerStack objectAtIndex:count - 1];
    } else {
        codec.currentContainer = nil;
    }
    return FTCRASHJSON_OK;
}

static int onEndData(__unused void *const userData) { return FTCRASHJSON_OK; }

static int addJSONData(const char *const bytes, const int length, void *const userData)
{
    NSMutableData *data = (__bridge NSMutableData *)userData;
    [data appendBytes:bytes length:(unsigned)length];
    return FTCRASHJSON_OK;
}

static int encodeObject(FTCrashJSONCodec *codec, id object, NSString *name, FTCrashJSONEncodeContext *context)
{
    int result;
    const char *cName = [name UTF8String];
    if ([object isKindOfClass:[NSString class]]) {
        NSData *data = [object dataUsingEncoding:NSUTF8StringEncoding];
        result = ftcrashjson_addStringElement(context, cName, data.bytes, (int)data.length);
        if (result == FTCRASHJSON_ERROR_INVALID_CHARACTER) {
            codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                                      code:0
                                               description:@"Invalid character in %@", object];
        }
        return result;
    }

    if ([object isKindOfClass:[NSNumber class]]) {
        CFNumberType numberType = CFNumberGetType((__bridge CFNumberRef)object);
        switch (numberType) {
            case kCFNumberFloat32Type:
            case kCFNumberFloat64Type:
            case kCFNumberFloatType:
            case kCFNumberCGFloatType:
            case kCFNumberDoubleType:
                return ftcrashjson_addFloatingPointElement(context, cName, [object doubleValue]);
            case kCFNumberCharType:
                // Char could be signed or unsigned, so we need to check its value
                if ([object charValue] == 0 || [object charValue] == 1) {
                    return ftcrashjson_addBooleanElement(context, cName, [object boolValue]);
                }
                // Fall through to integer handling if it's not a boolean
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-fallthrough"
            case kCFNumberSInt8Type:
#pragma clang diagnostic pop
            case kCFNumberSInt16Type:
            case kCFNumberSInt32Type:
            case kCFNumberSInt64Type:
            case kCFNumberShortType:
            case kCFNumberIntType:
            case kCFNumberLongType:
            case kCFNumberLongLongType:
            case kCFNumberNSIntegerType:
            case kCFNumberCFIndexType:
                // Check if the value is negative
                if ([object compare:@0] == NSOrderedAscending) {
                    return ftcrashjson_addIntegerElement(context, cName, [object longLongValue]);
                } else {
                    // Non-negative value, could be larger than LLONG_MAX
                    return ftcrashjson_addUIntegerElement(context, cName, [object unsignedLongLongValue]);
                }
            default: {
                // For any unhandled types, try unsigned first, then fall back to signed if needed
                unsigned long long unsignedValue = [object unsignedLongLongValue];
                if (unsignedValue > LLONG_MAX) {
                    return ftcrashjson_addUIntegerElement(context, cName, unsignedValue);
                } else {
                    return ftcrashjson_addIntegerElement(context, cName, [object longLongValue]);
                }
            }
        }
    }

    if ([object isKindOfClass:[NSArray class]]) {
        if ((result = ftcrashjson_beginArray(context, cName)) != FTCRASHJSON_OK) {
            return result;
        }
        for (id subObject in object) {
            if ((result = encodeObject(codec, subObject, NULL, context)) != FTCRASHJSON_OK) {
                return result;
            }
        }
        return ftcrashjson_endContainer(context);
    }

    if ([object isKindOfClass:[NSDictionary class]]) {
        if ((result = ftcrashjson_beginObject(context, cName)) != FTCRASHJSON_OK) {
            return result;
        }
        NSArray *keys = [(NSDictionary *)object allKeys];
        if (codec.sorted) {
            keys = [keys sortedArrayUsingSelector:@selector(compare:)];
        }
        for (id key in keys) {
            if ([key isKindOfClass:[NSString class]] == NO) {
                codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                                          code:0
                                                   description:@"Invalid key: %@", key];
                return FTCRASHJSON_ERROR_INVALID_DATA;
            }
            if ((result = encodeObject(codec, [object valueForKey:key], key, context)) != FTCRASHJSON_OK) {
                return result;
            }
        }
        return ftcrashjson_endContainer(context);
    }

    if ([object isKindOfClass:[NSNull class]]) {
        return ftcrashjson_addNullElement(context, cName);
    }

    if ([object isKindOfClass:[NSDate class]]) {
        char string[FTCRASHDATE_BUFFERSIZE] = { 0 };
        time_t timestamp = (time_t)((NSDate *)object).timeIntervalSince1970;
        ftcrashdate_utcStringFromTimestamp(timestamp, string, FTCRASHDATE_BUFFERSIZE);
        NSData *data = [NSData dataWithBytes:string length:strnlen(string, FTCRASHDATE_BUFFERSIZE - 1)];
        return ftcrashjson_addStringElement(context, cName, data.bytes, (int)data.length);
    }

    if ([object isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)object;
        return ftcrashjson_addDataElement(context, cName, data.bytes, (int)data.length);
    }

    codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                              code:0
                                       description:@"Could not determine type of %@", [object class]];
    return FTCRASHJSON_ERROR_INVALID_DATA;
}

#pragma mark Public API

+ (NSData *)encode:(id)object options:(FTCrashJSONEncodeOption)encodeOptions error:(NSError *__autoreleasing *)error
{
    NSMutableData *data = [NSMutableData data];
    FTCrashJSONEncodeContext JSONContext;
    ftcrashjson_beginEncode(&JSONContext, encodeOptions & FTCrashJSONEncodeOptionPretty, addJSONData, (__bridge void *)data);
    FTCrashJSONCodec *codec = [self codecWithEncodeOptions:encodeOptions decodeOptions:FTCrashJSONDecodeOptionNone];

    int result = encodeObject(codec, object, NULL, &JSONContext);
    if (error != NULL) {
        *error = codec.error;
    }
    return result == FTCRASHJSON_OK ? data : nil;
}

+ (id)decode:(NSData *)JSONData options:(FTCrashJSONDecodeOption)decodeOptions error:(NSError *__autoreleasing *)error
{
    FTCrashJSONCodec *codec = [self codecWithEncodeOptions:0 decodeOptions:decodeOptions];
    const size_t decodeMaxStringSize = 20000000;
    NSMutableData *stringBuffer = [NSMutableData dataWithLength:decodeMaxStringSize];
    int errorOffset;
    int result = ftcrashjson_decode(JSONData.bytes, (int)JSONData.length, stringBuffer.mutableBytes,
                               (int)stringBuffer.length, codec.callbacks, (__bridge void *)codec, &errorOffset);
    if (result != FTCRASHJSON_OK && codec.error == nil) {
        codec.error = [FTCrashNSErrorHelper errorWithDomain:@"FTCrashJSONCodecObjC"
                                                  code:0
                                           description:@"%s (offset %d)", ftcrashjson_stringForError(result), errorOffset];
    }
    if (error != NULL) {
        *error = codec.error;
    }

    if (result != FTCRASHJSON_OK && !(decodeOptions & FTCrashJSONDecodeOptionKeepPartialObject)) {
        return nil;
    }
    return codec.topLevelContainer;
}

@end
