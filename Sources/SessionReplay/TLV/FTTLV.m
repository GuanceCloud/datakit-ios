//
//  FTTLV.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/24.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTTLV.h"
NSUInteger const FT_MAX_DATA_LENGTH = 10*1024*1024;

@implementation FTTLV
-(instancetype)initWithType:(uint16_t)type value:(NSData *)value{
    self = [super init];
    if(self){
        _type = type;
        _value = value;
    }
    return self;
}
///         int16_t       int32_t
///     +-  2 bytes -+-   4 bytes   -+- n bytes -|
///     | block type | data size (n) |    data   |
///     +------------+---------------+-----------+
- (NSData *)serialize{
    return [self serialize:FT_MAX_DATA_LENGTH];
}
-(NSData *)serialize:(UInt64)maxLength{
    if(_value.length<=maxLength){
        NSMutableData *data = [NSMutableData data];
        NSData *typeData = [NSData dataWithBytes:&_type length:sizeof(_type)];
        int32_t length = (int32_t)_value.length;
        NSData *lengthData = [NSData dataWithBytes:&length length:sizeof(length)];
        
        [data appendData:typeData];
        [data appendData:lengthData];
        [data appendData:_value];
        return data;
    }
    return nil;
}
@end

#endif
