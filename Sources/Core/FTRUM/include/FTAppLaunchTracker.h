//
//  FTAppLaunchTracker.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
/// App cold and hot launch protocol
@protocol FTAppLaunchDataDelegate <NSObject>

/// App hot start
/// - Parameter duration: Launch duration
-(void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration ;

/// App cold start
/// - Parameters:
///   - duration: Launch duration
///   - isPreWarming: Whether prewarming occurred
///   - fields: performance fields
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming fields:(NSDictionary *)fields;
@optional
- (void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)prewarm
               fields:(NSDictionary *)fields endDate:(NSDate *)endDate;
@end
/// Internal sink retaining the actual launch endpoint independently of calibrated duration.
@protocol FTLaunchDataSink <NSObject>
- (void)addLaunch:(NSString *)name type:(NSString *)type launchTime:(NSDate *)time
         duration:(NSNumber *)duration property:(nullable NSDictionary *)property endDate:(NSDate *)endDate;
@end
@interface FTAppLaunchTracker : NSObject
@property (class, nonatomic, strong) NSDate *sdkStartDate;
@property (nonatomic, weak, nullable) id<FTAppLaunchDataDelegate> delegate;
+ (void)prewarmCheckStart;
+ (void)prewarmCheckEnd;
- (instancetype)initWithDelegate:(nullable id)delegate;
- (instancetype)initWithDelegate:(nullable id)delegate launchPrewarmInterval:(NSInteger)interval;
/// Stop this tracker without resetting process-scoped initial-launch ownership.
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
