//
//  FTLogMessage.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTLogMessage.h"

@implementation FTLogMessage
- (instancetype)initWithMessage:(NSString *)message level:(LogStatus)level function:(NSString *)function line:(NSUInteger)line timestamp:(NSDate *)timestamp {
    if (self = [super init]) {
        _message = [message copy];
        _level = level;
        _function = [function copy];
        _line = line;
        _timestamp = timestamp;
        _userLog = NO;
    }
    return self;
}
-(instancetype)initWithMessage:(NSString *)message level:(LogStatus)level status:(NSString *)status property:(nullable NSDictionary *)property timestamp:(nonnull NSDate *)timestamp{
    if (self = [super init]) {
        _message = [message copy];
        _level = level;
        _status = [status copy];
        _timestamp = timestamp;
        _property = [property copy];
        _userLog = YES;
    }
    return self;
}

@end
