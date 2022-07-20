//
//  FTReadWriteHelper.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTReadWriteHelper.h"
@interface FTReadWriteHelper<ValueType>()
@property (nonatomic, strong) ValueType value;
@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end
@implementation FTReadWriteHelper
-(instancetype)initWithValue:(id)value{
    self = [super init];
    if (self) {
        _value = value;
        _semaphore = dispatch_semaphore_create(0);

        _concurrentQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.ft.value.readwrite.%@",_value] UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
- (void)concurrentRead:(void (^)(id value))block{
    dispatch_sync(self.concurrentQueue, ^{
        block(self.value);
    });
}
- (void)concurrentWrite:(void (^)(id value))block{
    dispatch_barrier_async(self.concurrentQueue, ^{
        block(self.value);
    });
}
- (id)currentValue{
    __block id returnValue;
    [self concurrentRead:^(id  _Nonnull value) {
        returnValue = value;
        dispatch_semaphore_signal(self.semaphore);
    }];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    return returnValue;
}
@end
