//
//  FTAppLaunchTracker.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming;
@end
@interface FTAppLaunchTracker : NSObject
@property (class,nonatomic,assign) NSTimeInterval processStartTime;
@property (nonatomic,weak) id<FTAppLaunchDataDelegate> delegate;
- (instancetype)initWithDelegate:(nullable id)delegate;
@end

NS_ASSUME_NONNULL_END
