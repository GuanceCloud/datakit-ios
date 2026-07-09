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
@class FTDisplayRateMonitor;
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
@end
@interface FTAppLaunchTracker : NSObject
@property (class, nonatomic, strong) NSDate *sdkStartDate;
@property (nonatomic, weak, nullable) id<FTAppLaunchDataDelegate> delegate;
- (instancetype)initWithDelegate:(nullable id)delegate displayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor;

@end

NS_ASSUME_NONNULL_END
