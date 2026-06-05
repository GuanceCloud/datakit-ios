//
//  FTSerialTimer.h
//  FTMobileSDK
//
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSerialTimer : NSObject
- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)eventHandler;
- (void)scheduleAfter:(NSTimeInterval)delay leeway:(NSTimeInterval)leeway;
- (void)cancel;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
#endif
