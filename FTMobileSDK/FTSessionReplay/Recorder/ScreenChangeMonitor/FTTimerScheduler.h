//
//  FTTimerScheduler.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@protocol FTScheduledTimer <NSObject>
- (void)cancel;
@end

@protocol FTTimeSource <NSObject>
@property (nonatomic, assign, readonly) NSTimeInterval now;
@end

@protocol FTTimerScheduler <FTTimeSource>

- (id<FTScheduledTimer>)scheduleAfterInterval:(NSTimeInterval)interval action:(dispatch_block_t)action;

@end



@interface FTDispatchSourceScheduledTimer : NSObject <FTScheduledTimer>

- (instancetype)initWithDispatchSourceTimer:(dispatch_source_t)timer;

@end

@interface FTDispatchSourceTimerScheduler : NSObject <FTTimerScheduler>

@property (nonatomic, strong, readonly) dispatch_queue_t queue;

- (instancetype)initWithQueue:(dispatch_queue_t)queue;

+ (instancetype)scheduler;

@property (class, nonatomic, readonly) FTDispatchSourceTimerScheduler *dispatchSource;
@end

NS_ASSUME_NONNULL_END
