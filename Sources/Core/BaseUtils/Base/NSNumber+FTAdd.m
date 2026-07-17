//
//  NSNumber+FTAdd.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/25.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#import "NSNumber+FTAdd.h"

@implementation NSNumber (FTAdd)

- (BOOL)ft_isBool {
    return [self isKindOfClass:NSClassFromString(@"__NSCFBoolean")];
}

- (id)ft_toFieldFormat{
    if ([self ft_isBool]) {
        return [self boolValue] ? @"true": @"false";
    }if (strcmp([self objCType], @encode(float)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.floatValue];
    }else if(strcmp([self objCType], @encode(double)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.doubleValue];
    }else{
        return [NSString stringWithFormat:@"%@i", self];
    }
    return self;
}
- (id)ft_toFieldIntegerCompatibleFormat{
    if ([self ft_isBool]) {
        return [self boolValue] ? @"true": @"false";
    }if (strcmp([self objCType], @encode(float)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.floatValue];
    }else if(strcmp([self objCType], @encode(double)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.doubleValue];
    }
    return self;
}
- (id)ft_toTagFormat{
    if ([self ft_isBool]) {
        return [self boolValue] ? @"true": @"false";
    }else if (strcmp([self objCType], @encode(float)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.floatValue];
    }else if(strcmp([self objCType], @encode(double)) == 0){
        return [NSString stringWithFormat:@"%.2f",self.doubleValue];
    }
    return self;
}
- (id)ft_toUserFieldFormat{
   if (strcmp([self objCType], @encode(float)) == 0||strcmp([self objCType], @encode(double)) == 0){
       return self.stringValue;
    }
    return self;
}
@end
