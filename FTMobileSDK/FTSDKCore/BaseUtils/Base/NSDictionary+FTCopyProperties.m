//
//  NSDictionary+FTCopyProperties.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "NSDictionary+FTCopyProperties.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "NSNumber+FTAdd.h"

@implementation NSDictionary (FTCopyProperties)
- (BOOL)ft_hasValidValueForKey:(NSString *)key {
    id value = key.length > 0 ? self[key] : nil;
    return value && ![value isKindOfClass:NSNull.class];
}
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

@implementation NSObject (FTSafeDictionary)
+ (NSDictionary *)ft_normalizedDictionaryWithObject:(id)object {
    if (![object isKindOfClass:NSDictionary.class]) {
        return @{};
    }
    return [(NSDictionary *)object copy] ?: @{};
}
@end

@implementation FTLinePropertyBag
- (instancetype)initWithTags:(id)tags fields:(id)fields {
    self = [super init];
    if (self) {
        _tags = [NSObject ft_normalizedDictionaryWithObject:tags];
        _fields = [NSObject ft_normalizedDictionaryWithObject:fields];
        NSMutableDictionary *merged = [NSMutableDictionary dictionary];
        [merged addEntriesFromDictionary:_tags];
        [merged addEntriesFromDictionary:_fields];
        _mergedDictionary = [merged copy];
    }
    return self;
}
- (FTLinePropertyBag *)bagByApplyingChangedValues:(id)changedValues {
    NSDictionary *safeChangedValues = [NSObject ft_normalizedDictionaryWithObject:changedValues];
    if (safeChangedValues.count == 0) {
        return self;
    }
    NSMutableDictionary *mutableTags = [self.tags mutableCopy];
    NSMutableDictionary *mutableFields = [self.fields mutableCopy];
    NSSet *tagKeys = [NSSet setWithArray:self.tags.allKeys];
    NSSet *fieldKeys = [NSSet setWithArray:self.fields.allKeys];
    [safeChangedValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([tagKeys containsObject:key]) {
            mutableTags[key] = obj;
        } else if ([fieldKeys containsObject:key]) {
            mutableFields[key] = obj;
        }
    }];
    return [[FTLinePropertyBag alloc] initWithTags:mutableTags fields:mutableFields];
}
@end
