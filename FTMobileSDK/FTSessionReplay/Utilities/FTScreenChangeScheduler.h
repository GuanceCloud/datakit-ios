//
//  FTScreenChangeScheduler.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/2.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTTimerScheduler.h"
#import "FTScheduler.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTScreenChangeScheduler : NSObject<FTScheduler>

@property (nonatomic, assign, readonly) NSTimeInterval minimumInterval;

@property (nonatomic, strong, readonly) id<FTTimerScheduler> timerScheduler;


- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval
                         timerScheduler:(id<FTTimerScheduler>)timerScheduler;


- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
