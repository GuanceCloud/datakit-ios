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
#import "FTRUMViewTimingPredicates.h"
NS_ASSUME_NONNULL_BEGIN
/// RUM-queue-owned event-time summary. It may outlive its View handler for INV.
@interface FTRUMViewMetrics : NSObject
@property (nonatomic, assign, readonly) long long startNs;
- (instancetype)initWithStartNs:(long long)startNs predicate:(nullable id<FTRUMNextViewActionPredicate>)predicate;
- (void)moveStartEarlierTo:(long long)startNs;
- (void)recordActionStart:(long long)startNs name:(NSString *)name type:(NSString *)type;
- (nullable NSNumber *)interactionToViewAt:(long long)nextStartNs name:(NSString *)nextViewName;
@end
NS_ASSUME_NONNULL_END
