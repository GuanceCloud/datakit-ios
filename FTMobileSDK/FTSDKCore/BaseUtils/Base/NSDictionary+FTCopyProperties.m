//
//  NSDictionary+FTCopyProperties.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "NSDictionary+FTCopyProperties.h"
#import "FTLog+Private.h"
@implementation NSDictionary (FTCopyProperties)
- (NSDictionary *)ft_deepCopy{
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    @try {
        NSArray *allKeys = [self allKeys];
        for (id key in allKeys) {
            id value = [self objectForKey:key];
            if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSDate class]]) {
                properties[key] = [value copy];
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
            properties[key] = value;
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
    if (![NSJSONSerialization isValidJSONObject:object]) {
        return nil;
    }
    @try {
        NSError *error;
        NSData *objectData = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
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
