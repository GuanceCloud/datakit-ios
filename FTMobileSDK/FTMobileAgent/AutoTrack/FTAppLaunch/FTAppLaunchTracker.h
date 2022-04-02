//
//  FTAppLaunchTracker.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTAppLaunchDataDelegate <NSObject>

-(void)ftAppHotStart:(NSNumber *)duration;

-(void)ftAppColdStart:(NSNumber *)duration;
@end
@interface FTAppLaunchTracker : NSObject
@property (nonatomic,weak) id<FTAppLaunchDataDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
