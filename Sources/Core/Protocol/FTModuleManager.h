//
//  FTModuleManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/10.
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
NS_ASSUME_NONNULL_BEGIN
typedef NSString *FTMessageKey NS_STRING_ENUM;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRUMContext;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRecordsCountByViewID;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySessionHasReplay;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyWebViewSR;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRumError;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySRSampleRateUpdate;
@protocol FTMessageReceiver;

@interface FTModuleManager : NSObject
+ (instancetype)sharedInstance;
- (void)postMessageWithKey:(NSString *)key messageBlock:(nullable NSDictionary * (^)(void))messageBlock;
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message;
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message sync:(BOOL)sync;

/// Add delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver;
/// Remove delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver;

- (void)registerService:(Protocol *)service instance:(id)instance;

- (id)getRegisterService:(Protocol *)protocol;
@end

NS_ASSUME_NONNULL_END
