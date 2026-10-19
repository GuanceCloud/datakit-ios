//
//  FTRUMViewMetrics.h
//  FTMobileAgent
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
@class FTRUMAppStateHistory;
NS_ASSUME_NONNULL_BEGIN
/// RUM-queue-owned event-time summary. It may outlive its View handler for INV.
@interface FTRUMViewMetrics : NSObject
@property (nonatomic, assign, readonly) long long startNs;
@property (nonatomic, assign, readonly) BOOL hasInitialResource;
/// A reservation-only fallback is invisible until actual admission.
@property (nonatomic, strong, nullable) FTRUMViewMetrics *ignoredPredecessor;
- (instancetype)initWithStartNs:(long long)startNs;
- (void)moveStartEarlierTo:(long long)startNs;
- (void)recordClickStart:(long long)startNs;
- (nullable NSNumber *)interactionToViewAt:(long long)nextStartNs;
- (void)recordResourceStart:(long long)startNs end:(long long)endNs;
- (nullable NSNumber *)networkSettledTimeWithHistory:(nullable FTRUMAppStateHistory *)history;
@end
NS_ASSUME_NONNULL_END
