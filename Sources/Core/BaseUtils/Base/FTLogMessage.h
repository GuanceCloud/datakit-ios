//
//  FTLogMessage.h
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

#import <Foundation/Foundation.h>
#import "FTInternalConstants.h"
NS_ASSUME_NONNULL_BEGIN


@interface FTLogMessage : NSObject
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, assign, readonly) LogStatus level;
@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy, readonly) NSString *function;
@property (nonatomic, assign, readonly) NSUInteger line;
@property (nonatomic, strong, readonly) NSDate *timestamp;
@property (nonatomic, assign) BOOL userLog;
@property (nonatomic, copy, readonly) NSDictionary *property;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithMessage:(NSString *)message
                          level:(LogStatus)level
                       function:(NSString *)function
                           line:(NSUInteger)line
                      timestamp:(NSDate *)timestamp;
-(instancetype)initWithMessage:(NSString *)message
                         level:(LogStatus)level
                        status:(nullable NSString *)status
                      property:(nullable NSDictionary *)property
                     timestamp:(nonnull NSDate *)timestamp;
@end

NS_ASSUME_NONNULL_END
