//
//  FTAppLaunchTracker.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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
@property (class, nonatomic, assign) NSDate *sdkStartDate;
@property (nonatomic,weak) id<FTAppLaunchDataDelegate> delegate;
- (instancetype)initWithDelegate:(nullable id)delegate displayMonitor:( FTDisplayRateMonitor *)displayMonitor;
@end

NS_ASSUME_NONNULL_END
