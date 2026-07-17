//
//  FTSerialNumberGenerator.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/12.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
