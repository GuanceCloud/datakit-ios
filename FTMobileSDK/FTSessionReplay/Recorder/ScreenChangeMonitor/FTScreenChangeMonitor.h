//
//  FTScreenChangeMonitor.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/2.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTCALayerChangeSnapshot.h"
#import "FTTimerScheduler.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTScreenChangeMonitor : NSObject
- (instancetype)initWithMinimumDeliveryInterval:(NSTimeInterval)minimumDeliveryInterval
                                 timerScheduler:(id<FTTimerScheduler>)timerScheduler
                                        handler:(void (^)(FTCALayerChangeSnapshot *snapshot))handler;

- (instancetype)initWithMinimumDeliveryInterval:(NSTimeInterval)minimumDeliveryInterval
                                        handler:(void (^)(FTCALayerChangeSnapshot *snapshot))handler;
                    

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)start;

- (void)stop;
@end

NS_ASSUME_NONNULL_END
