//
//  FTLogMessage.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
