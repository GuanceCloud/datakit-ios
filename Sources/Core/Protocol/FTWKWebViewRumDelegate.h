//
//  FTWKWebViewRumDelegate.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/11/18.
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

#ifndef FTWKWebViewRumDelegate_h
#define FTWKWebViewRumDelegate_h
NS_ASSUME_NONNULL_BEGIN
@protocol FTWKWebViewRumDelegate <NSObject>
@required
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
- (NSString *)getLastHasReplayViewID;
- (void)bindSRInfo:(nullable NSDictionary *)info containerViewID:(NSString *)viewID;
- (nullable NSString *)getLastViewName;
@end
NS_ASSUME_NONNULL_END
#endif /* FTWKWebViewRumDelegate_h */
