//
//  NSNumber+FTAdd.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/25.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "NSNumber+FTAdd.h"

@implementation NSNumber (FTAdd)

- (BOOL)ft_isBool {
    return [self isKindOfClass:NSClassFromString(@"__NSCFBoolean")];
}

- (NSString *)ft_toFiledString{
    if ([self ft_isBool]) {
        return [self boolValue] ? @"true": @"false";
    }if (strcmp([self objCType], @encode(float)) == 0){
        return [NSString stringWithFormat:@"%.1f",self.floatValue];
    }else if(strcmp([self objCType], @encode(double)) == 0){
        return [NSString stringWithFormat:@"%.1f",self.doubleValue];
    }else{
        return [NSString stringWithFormat:@"%@i", self];
    }
    return self.stringValue;
}
- (id)ft_toTagFormat{
    if ([self ft_isBool]) {
        return [self boolValue] ? @"true": @"false";
    }else{
        return self;
    }
}
@end
