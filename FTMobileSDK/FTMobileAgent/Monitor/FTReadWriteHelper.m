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
    }
    return self;
}

@end
