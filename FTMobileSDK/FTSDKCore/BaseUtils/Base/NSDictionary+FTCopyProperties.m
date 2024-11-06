//
//  NSDictionary+FTCopyProperties.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "NSDictionary+FTCopyProperties.h"
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
#import "NSNumber+FTAdd.h"
@implementation NSDictionary (FTCopyProperties)
- (NSDictionary *)ft_deepCopy{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    @try {
        NSArray *allKeys = [self allKeys];
        for (id key in allKeys) {
            NSString *stringKey = key;
            if(![key isKindOfClass:[NSString class]]){
                stringKey = [key description];
                FTInnerLogWarning(@"%@ :All dictionary keys should be NSStrings",self);
            }
            id value = [self objectForKey:key];
            if ([value isKindOfClass:[NSString class]]) {
                properties[key] = [value copy];
                continue;
            }
            if([value isKindOfClass:[NSNumber class]]){
                NSNumber *number = (NSNumber *)value;
                id rValue = [number isEqualToNumber:NSDecimalNumber.notANumber] || [number isEqualToNumber:@(INFINITY)] ? nil : [number ft_toUserFieldFormat];
                properties[key] = rValue;
                continue;
            }
            if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                properties[key] = [self ft_copyArrayOrDictionary:value];
                continue;
            }
            if ([value isKindOfClass:[NSSet class]]) {
                NSSet *set = value;
                properties[key] = [self ft_copyArrayOrDictionary:[set allObjects]];
                continue;
            }
            properties[key] = [value description];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@", exception);
    } @finally {
        return [properties copy];
    }
}
- (id)ft_copyArrayOrDictionary:(id)object {
    if (!object) {
        return nil;
    }
    id safeObject = [FTJSONUtil JSONSerializableObject:object];
    if (![NSJSONSerialization isValidJSONObject:safeObject]) {
        FTInnerLogError(@"All objects need be NSString, NSNumber, NSArray, NSDictionary, or NSNull. NSNumbers are not NaN or infinity");
        return nil;
    }
    @try {
        NSError *error;
        NSData *objectData = [NSJSONSerialization dataWithJSONObject:safeObject options:NSJSONWritingPrettyPrinted error:&error];
        id tempObject = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingFragmentsAllowed error:&error];
        if (error) {
            FTInnerLogError(@"%@", error.localizedDescription);
            return nil;
        }
        return tempObject;
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@", exception);
    }
}
@end
