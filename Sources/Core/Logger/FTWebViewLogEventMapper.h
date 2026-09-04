//
//  FTWebViewLogEventMapper.h
//  GuanceSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

NS_ASSUME_NONNULL_BEGIN

@interface FTWebViewLogEvent : NSObject
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSDictionary *tags;
@property (nonatomic, copy) NSDictionary *fields;
@property (nonatomic, assign) long long time;
@end

@interface FTWebViewLogEventMapper : NSObject
+ (nullable FTWebViewLogEvent *)mapEvent:(NSDictionary *)event;
+ (void)removeRumLinkDataFromEvent:(FTWebViewLogEvent *)event;
+ (void)replaceRumLinkDataInEvent:(FTWebViewLogEvent *)event
                    applicationId:(nullable NSString *)applicationId
                         sessionId:(nullable NSString *)sessionId;
@end

NS_ASSUME_NONNULL_END
