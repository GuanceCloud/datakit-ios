//
//  FTRUMContext.h
//
//  Created by hulilei on 2025/12/22.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTDictionaryConvertible;

@interface FTRUMSessionState : NSObject<FTDictionaryConvertible>
// session tags
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
// view session fields
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sessionOnErrorSampleRate;
@property (nonatomic, assign) long long session_error_timestamp;
@property (nonatomic, assign) BOOL sampled_for_error_session;

- (NSDictionary *)sessionTags;
- (NSDictionary *)sessionFields;

@end

@interface FTRUMContext : NSObject
@property (nonatomic, copy) NSString *appId;

@property (nonatomic, strong, readonly) FTRUMSessionState *sessionState;

@property (nonatomic, copy, nullable) NSString *view_id;
@property (nonatomic, copy, nullable) NSString *view_name;
@property (nonatomic, copy, nullable) NSString *view_referrer;
@property (nonatomic, copy, nullable) NSString *action_id;
@property (nonatomic, copy, nullable) NSString *action_name;

- (instancetype)initWithSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate appId:(NSString *)appId;

- (instancetype)init NS_UNAVAILABLE;

/// trace, logger get rum correlation data
-(NSDictionary *)getGlobalSessionViewTags;
/// rum internal get related correlation data
-(NSDictionary *)getGlobalSessionViewActionTags;

-(NSDictionary *)getGlobalSessionTags;

@end

NS_ASSUME_NONNULL_END
