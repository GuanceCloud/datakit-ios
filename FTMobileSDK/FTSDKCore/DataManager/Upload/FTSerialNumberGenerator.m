//
//  FTSerialNumberGenerator.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTSerialNumberGenerator.h"
@interface FTSerialNumberGenerator()
@property (nonatomic, assign) long currentValue;
@end
@implementation FTSerialNumberGenerator
-(instancetype)initWithPrefix:(NSString *)prefix{
    self = [super init];
    if(self){
        _currentValue = 0;
        _prefix = prefix;
    }
    return self;
}
- (void)increaseRequestSerialNumber{
    if(_currentValue == ULONG_MAX){
        _currentValue = 0;
    }else{
        _currentValue += 1;
    }
}
- (NSString *)getCurrentSerialNumber{
    return [self decimalToBase36:_currentValue];
}
- (NSString *)decimalToBase36:(unsigned long)decimalNumber{
    static NSString *const base36Characters = @"0123456789abcdefghijklmnopqrstuvwxyz";
    NSMutableString *result = [NSMutableString string];
    while (decimalNumber > 0) {
        NSUInteger remainder = decimalNumber % 36;
        [result insertString:[base36Characters substringWithRange:NSMakeRange(remainder, 1)] atIndex:0];
        decimalNumber /= 36;
    }
    return result.length > 0 ? result : @"0";
}
@end
