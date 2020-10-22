//
//  FTJsonWriter.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTJsonWriter.h"
@class FTJsonWriterState;

@interface FTJsonWriterState : NSObject
- (BOOL)isInvalidState:(FTJsonWriter *)writer;
- (void)appendSeparator:(FTJsonWriter *)writer;
- (BOOL)expectingKey:(FTJsonWriter *)writer;
- (void)transitionState:(FTJsonWriter *)writer;
- (void)appendWhitespace:(FTJsonWriter *)writer;
@end
@interface FTJsonWriter ()
@property (nonatomic, strong) FTJsonWriterState *stateObjectStart,
*stateObjectKey,
*stateObjectValue,
*stateArrayStart,
*stateArrayValue,
*state;
@property (nonatomic, readonly, strong) NSMutableArray *stateStack;
@end

@interface FTJsonWriterStateObjectStart : FTJsonWriterState
@end

@interface FTJsonWriterStateObjectKey : FTJsonWriterStateObjectStart
@end

@interface FTJsonWriterStateObjectValue : FTJsonWriterState
@end

@interface FTJsonWriterStateArrayStart : FTJsonWriterState
@end

@interface FTJsonWriterStateArrayValue : FTJsonWriterState
@end

@interface FTJsonWriterStateStart : FTJsonWriterState
@end

@interface FTJsonWriterStateComplete : FTJsonWriterState
@end
@implementation FTJsonWriterState
- (BOOL)isInvalidState:(FTJsonWriter *)writer { return NO; }
- (void)appendSeparator:(FTJsonWriter *)writer {}
- (BOOL)expectingKey:(FTJsonWriter *)writer { return NO; }
- (void)transitionState:(FTJsonWriter *)writer {}
- (void)appendWhitespace:(FTJsonWriter *)writer {
    [writer appendBytes:"\n" length:1];
    for (NSUInteger i = 0; i < writer.stateStack.count; i++)
        [writer appendBytes:"  " length:2];
}
@end

@implementation FTJsonWriterStateObjectStart
- (void)transitionState:(FTJsonWriter *)writer {
    writer.state = writer.stateObjectValue;
}
- (BOOL)expectingKey:(FTJsonWriter *)writer {
    writer.error = @"JSON object key must be string";
    return YES;
}
- (void)appendWhitespace:(FTJsonWriter *)writer {
    [writer appendBytes:" " length:1];
}
@end

@implementation FTJsonWriterStateObjectKey
- (void)appendSeparator:(FTJsonWriter *)writer {
    [writer appendBytes:"," length:1];
}
@end

@implementation FTJsonWriterStateObjectValue
- (void)appendSeparator:(FTJsonWriter *)writer {
    [writer appendBytes:":" length:1];
}
- (void)transitionState:(FTJsonWriter *)writer {
    writer.state = writer.stateObjectKey;
}
- (void)appendWhitespace:(FTJsonWriter *)writer {
    [writer appendBytes:" " length:1];
}
@end

@implementation FTJsonWriterStateArrayStart
- (void)transitionState:(FTJsonWriter *)writer {
    writer.state = writer.stateArrayValue;
}
@end

@implementation FTJsonWriterStateArrayValue
- (void)appendSeparator:(FTJsonWriter *)writer {
    [writer appendBytes:"," length:1];
}
@end

@implementation FTJsonWriterStateStart
- (void)transitionState:(FTJsonWriter *)writer {
    writer.state = [[FTJsonWriterStateComplete alloc] init];
}
- (void)appendSeparator:(FTJsonWriter *)writer {
}
@end

@implementation FTJsonWriterStateComplete
- (BOOL)isInvalidState:(FTJsonWriter *)writer {
    writer.error = @"Stream is closed";
    return YES;
}
@end
@interface FTJsonWriter (){
    NSNumber *kTrue, *kFalse, *kPositiveInfinity, *kNegativeInfinity;
    __weak id<FTJsonWriterDelegate> _delegate;
    
}
@end
@implementation FTJsonWriter
+ (id)writerWithDelegate:(id<FTJsonWriterDelegate>)delegate
{
    return [[self alloc] initWithDelegate:delegate];
}
- (id)initWithDelegate:(id<FTJsonWriterDelegate>)delegate{
    self = [super init];
    if (self) {
        kPositiveInfinity = [NSNumber numberWithDouble:+HUGE_VAL];
        kNegativeInfinity = [NSNumber numberWithDouble:-HUGE_VAL];
        kTrue = [NSNumber numberWithBool:YES];
        kFalse = [NSNumber numberWithBool:NO];
        
        _stateObjectStart = [[FTJsonWriterStateObjectStart alloc] init];
        _stateObjectKey = [[FTJsonWriterStateObjectKey alloc] init];
        _stateObjectValue = [[FTJsonWriterStateObjectValue alloc] init];
        _stateArrayStart = [[FTJsonWriterStateArrayStart alloc] init];
        _stateArrayValue = [[FTJsonWriterStateArrayValue alloc] init];
        _state = [[FTJsonWriterStateStart alloc] init];
        
        _delegate = delegate;
        _stateStack = [[NSMutableArray alloc] initWithCapacity:32];
        cache = [[NSMutableDictionary alloc] initWithCapacity:32];
    }
    return self;
}
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
    [_delegate writer:self appendBytes:bytes length:length];
}
- (BOOL)writeObject:(NSDictionary *)dict {
    if (![self writeObjectOpen])
        return NO;
    
    NSArray *keys = [dict allKeys];
    
    
    keys = [keys sortedArrayUsingSelector:@selector(compare:)];
    
    
    for (id k in keys) {
        if (![k isKindOfClass:[NSString class]]) {
            self.error = [NSString stringWithFormat:@"JSON object key must be string: %@", k];
            return NO;
        }
        
        if (![self writeString:k])
            return NO;
        if (![self writeValue:[dict objectForKey:k]])
            return NO;
    }
    
    return [self writeObjectClose];
}
- (BOOL)writeValue:(id)o {
    if ([o isKindOfClass:[NSDictionary class]]) {
        return [self writeObject:o];
        
    } else if ([o isKindOfClass:[NSArray class]]) {
        return [self writeArray:o];
        
    } else if ([o isKindOfClass:[NSString class]]) {
        return [self writeString:o];
        
    } else if ([o isKindOfClass:[NSNumber class]]) {
        return [self writeNumber:o];
        
    } else if ([o isKindOfClass:[NSNull class]]) {
        return [self writeNull];
        
    }
    
    self.error = [NSString stringWithFormat:@"JSON serialisation not supported for %@", [o class]];
    return NO;
}
- (BOOL)writeArrayOpen {
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    [_state appendSeparator:self];
    [_stateStack addObject:_state];
    self.state = self.stateArrayStart;
    
    if (_stateStack.count > 32) {
        self.error = @"Nested too deep";
        return NO;
    }
    
    [_delegate writer:self appendBytes:"[" length:1];
    return YES;
}
- (BOOL)writeArray:(NSArray*)array {
    if (![self writeArrayOpen])
        return NO;
    for (id v in array)
        if (![self writeValue:v])
            return NO;
    return [self writeArrayClose];
}

- (BOOL)writeArrayClose {
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    FTJsonWriterState *prev = _state;
    
    self.state = [_stateStack lastObject];
    [_stateStack removeLastObject];
    [prev appendWhitespace:self];
    
    [_delegate writer:self appendBytes:"]" length:1];
    
    [_state transitionState:self];
    return YES;
}
- (BOOL)writeNull {
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    [_state appendSeparator:self];
    [_state appendWhitespace:self];
    [_delegate writer:self appendBytes:"null" length:4];
    [_state transitionState:self];
    return YES;
}
- (BOOL)writeNumber:(NSNumber*)number {
    if (number == kTrue || number == kFalse)
        return [self writeBool:[number boolValue]];
    
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    [_state appendSeparator:self];
    [_state appendWhitespace:self];
    if ([kPositiveInfinity isEqualToNumber:number]) {
        self.error = @"+Infinity is not a valid number in JSON";
        return NO;
        
    } else if ([kNegativeInfinity isEqualToNumber:number]) {
        self.error = @"-Infinity is not a valid number in JSON";
        return NO;
        
    } else if (isnan([number doubleValue])) {
        self.error = @"NaN is not a valid number in JSON";
        return NO;
    }
    
    const char *objcType = [number objCType];
    char num[128];
    int len;
    
    switch (objcType[0]) {
        case 'c': case 'i': case 's': case 'l': case 'q':
            len = snprintf(num, sizeof num, "%lld", [number longLongValue]);
            break;
        case 'C': case 'I': case 'S': case 'L': case 'Q':
            len = snprintf(num, sizeof num, "%llu", [number unsignedLongLongValue]);
            break;
        case 'f': case 'd': default: {
            len = snprintf(num, sizeof num, "%.17f", [number doubleValue]);
            break;
        }
    }
    
    // It is always safe to cast `len` to NSUInteger here, because
    // snprintf above guarantees its range is in the range 0 to 128
    // (the length of the `num` buffer).
    [_delegate writer:self appendBytes:num length: (NSUInteger)len];
    [_state transitionState:self];
    return YES;
}
- (BOOL)writeBool:(BOOL)x {
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    [_state appendSeparator:self];
    [_state appendWhitespace:self];
    if (x)
        [_delegate writer:self appendBytes:"true" length:4];
    else
        [_delegate writer:self appendBytes:"false" length:5];
    [_state transitionState:self];
    return YES;
}

- (BOOL)writeString:(NSString*)string {
    if ([_state isInvalidState:self]) return NO;
    [_state appendSeparator:self];
    [_state appendWhitespace:self];
    NSMutableData *buf = [cache objectForKey:string];
    if (!buf) {
        
        NSUInteger len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        const char *utf8 = [string UTF8String];
        NSUInteger written = 0, i = 0;
        
        buf = [NSMutableData dataWithCapacity:(NSUInteger)(len * 1.1f)];
        [buf appendBytes:"\"" length:1];
        
        for (i = 0; i < len; i++) {
            int c = utf8[i];
            BOOL isControlChar = c >= 0 && c < 32;
            if (isControlChar || c == '"' || c == '\\') {
                if (i - written)
                    [buf appendBytes:utf8 + written length:i - written];
                written = i + 1;
                
                const char *t = strForChar(c);
                [buf appendBytes:t length:strlen(t)];
            }
        }
        
        if (i - written)
            [buf appendBytes:utf8 + written length:i - written];
        
        [buf appendBytes:"\"" length:1];
        [cache setObject:buf forKey:string];
    }
    
    [_delegate writer:self appendBytes:[buf bytes] length:[buf length]];
    [_state transitionState:self];
    return YES;
}
static const char *strForChar(int c) {
    switch (c) {
        case 0: return "\\u0000";
        case 1: return "\\u0001";
        case 2: return "\\u0002";
        case 3: return "\\u0003";
        case 4: return "\\u0004";
        case 5: return "\\u0005";
        case 6: return "\\u0006";
        case 7: return "\\u0007";
        case 8: return "\\b";
        case 9: return "\\t";
        case 10: return "\\n";
        case 11: return "\\u000b";
        case 12: return "\\f";
        case 13: return "\\r";
        case 14: return "\\u000e";
        case 15: return "\\u000f";
        case 16: return "\\u0010";
        case 17: return "\\u0011";
        case 18: return "\\u0012";
        case 19: return "\\u0013";
        case 20: return "\\u0014";
        case 21: return "\\u0015";
        case 22: return "\\u0016";
        case 23: return "\\u0017";
        case 24: return "\\u0018";
        case 25: return "\\u0019";
        case 26: return "\\u001a";
        case 27: return "\\u001b";
        case 28: return "\\u001c";
        case 29: return "\\u001d";
        case 30: return "\\u001e";
        case 31: return "\\u001f";
        case 34: return "\\\"";
        case 92: return "\\\\";
        default:
            [NSException raise:@"Illegal escape char" format:@"-->%c<-- is not a legal escape character", c];
            return NULL;
    }
}
- (BOOL)writeObjectOpen {
    if ([_state isInvalidState:self]) return NO;
    if ([_state expectingKey:self]) return NO;
    [_state appendSeparator:self];
    if (_stateStack.count) [_state appendWhitespace:self];
    
    [_stateStack addObject:_state];
    self.state = self.stateObjectStart;
    
    if ( _stateStack.count > 32) {
        self.error = @"Nested too deep";
        return NO;
    }
    
    [_delegate writer:self appendBytes:"{" length:1];
    return YES;
}
- (BOOL)writeObjectClose {
    if ([_state isInvalidState:self]) return NO;
    FTJsonWriterState *prev = _state;
    
    
    self.state = [_stateStack lastObject];
    [_stateStack removeLastObject];
    [prev appendWhitespace:self];
    [_delegate writer:self appendBytes:"}" length:1];
    
    [_state transitionState:self];
    return YES;
}

@end
