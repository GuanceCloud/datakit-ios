//
//  FTQueue.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/2.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTQueue <NSObject>

- (void)run:(void (^)(void))block;

@end

@interface FTAsyncQueue : NSObject <FTQueue>

@property (nonatomic, strong) dispatch_queue_t queue;

- (instancetype)initWithQueue:(dispatch_queue_t)queue;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface FTBackgroundAsyncQueue : FTAsyncQueue


- (instancetype)initWithLabel:(NSString *)label
                          qos:(qos_class_t)qos
                   attributes:(dispatch_queue_attr_t)attributes
         autoreleaseFrequency:(dispatch_autorelease_frequency_t)autoreleaseFrequency
                       target:(nullable FTAsyncQueue *)target NS_DESIGNATED_INITIALIZER;


- (instancetype)initWithLabel:(NSString *)label;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface FTMainQueue : NSObject <FTQueue>

@end


NS_ASSUME_NONNULL_END
