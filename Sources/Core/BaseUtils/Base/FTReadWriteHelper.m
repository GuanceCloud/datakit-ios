//
//  FTReadWriteHelper.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/7.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
