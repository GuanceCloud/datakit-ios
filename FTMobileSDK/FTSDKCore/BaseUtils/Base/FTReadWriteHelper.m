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
@end
@implementation FTReadWriteHelper
-(instancetype)initWithValue:(id)value{
    self = [super init];
    if (self) {
        _value = value;
        _concurrentQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.ft.value.readwrite.%@",_value] UTF8String], DISPATCH_QUEUE_CONCURRENT);
        NSAssert([value conformsToProtocol:@protocol(NSCopying)],@"Need to implement %@ the copy method of this object, otherwise calling currentValue will cause a crash",NSStringFromClass([value class]));
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
    dispatch_sync(self.concurrentQueue, ^{
        returnValue = [self.value copy];
    });
    return returnValue;
}
@end
