//
//  FTScheduler.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/2.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "FTQueue.h"
#ifndef FTScheduler_h
#define FTScheduler_h

@protocol FTScheduler <NSObject>

@required

@property (nonatomic, strong, readonly) id<FTQueue> queue;


- (void)scheduleWithOperation:(void (^)(void))operation;

- (void)start;


- (void)stop;

@end

#endif /* FTScheduler_h */
