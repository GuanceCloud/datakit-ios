//
//  FTAppLaunchTracker.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// app 冷热启动协议
@protocol FTAppLaunchDataDelegate <NSObject>

/// app 热启动
/// - Parameter duration: 启动时长
-(void)ftAppHotStart:(NSNumber *)duration;

/// app 冷启动
/// - Parameters:
///   - duration: 启动时长
///   - isPreWarming: 是否产生了预热
-(void)ftAppColdStart:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming;
@end
@interface FTAppLaunchTracker : NSObject
@property (nonatomic,weak) id<FTAppLaunchDataDelegate> delegate;
- (instancetype)initWithDelegate:(nullable id)delegate;
@end

NS_ASSUME_NONNULL_END
