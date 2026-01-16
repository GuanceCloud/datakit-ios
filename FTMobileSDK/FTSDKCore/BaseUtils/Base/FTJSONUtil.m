//
//  FTJSONUtil.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
@interface FTJSONUtil ()
@end
@implementation FTJSONUtil

+ (NSString *)convertToJsonData:(NSDictionary *)dict{
    NSString *result = nil;
    @try {
        NSData *jsonData = [FTJSONUtil JSONSerializeDictObject:dict];
        if (jsonData) {
            result = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ exception encoding api data: %@", self, exception);
    }
    return result;
}
+ (nullable NSData *)JSONSerializeDictObject:(NSDictionary *)dict{
    if (!dict) return nil;

    if (![NSJSONSerialization isValidJSONObject:dict]) {
        FTInnerLogError(@"Object is not a valid JSON object: %@", dict);
        return nil;
    }
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error) {
        FTInnerLogError(@"JSON Serialization failed: %@", error.localizedDescription);
        return nil;
    }
    return jsonData;
}
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString{
    id result = [self objectWithJsonString:jsonString];
    return [result isKindOfClass:NSDictionary.class]?result:nil;
}
+ (NSArray *)arrayWithJsonString:(NSString *)jsonString{
    id result = [self objectWithJsonString:jsonString];
    return [result isKindOfClass:NSArray.class]?result:nil;
}
+ (id)objectWithJsonString:(NSString *)jsonString{
    id result = nil;
    @try {
        if (jsonString == nil || [jsonString isEqualToString:@""]) {
            return nil;
        }
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *err;
        result = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:0
                                                   error:&err];
        if(err){
            FTInnerLogError(@"JSON parsing failed: %@",err);
            return nil;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ exception encoding api data: %@", self, exception);
    }
    return result;
}
+ (NSString *)convertToJsonDataWithObject:(id)object{
    NSString *result = nil;
    @try {
        if (object == nil) {
            return nil;
        }
        NSError *err;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err];
        if(err){
            FTInnerLogError(@"JSON parsing failed: %@",err);
        }else{
            result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ exception encoding api data: %@", self, exception);
    }
    return result;
}
+ (id)JSONSerializableObject:(id)obj{
    // valid json types
    if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    }
    if ([obj isKindOfClass:[NSNull class]]) {
        return [obj description];
    }
    //Prevent NaN and infinity
    if ([obj isKindOfClass:[NSNumber class]]) {
        return [obj isEqualToNumber:NSDecimalNumber.notANumber] || [obj isEqualToNumber:@(INFINITY)] ? nil : obj;
    }
    // recurse on containers
    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        NSMutableArray *mutableArray = [NSMutableArray array];
        for (id value in obj) {
            id newValue = [self JSONSerializableObject:value];
            if (newValue) {
                [mutableArray addObject:newValue];
            }
        }
        return [NSArray arrayWithArray:mutableArray];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDic = [NSMutableDictionary dictionary];
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *stringKey = key;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                FTInnerLogWarning(@"property keys should be strings. but property: %@, type: %@, key: %@", obj, [key class], key);
            }
            mutableDic[stringKey] = [self JSONSerializableObject:obj];
        }];
        return [NSDictionary dictionaryWithDictionary:mutableDic];
    }

    if ([obj isKindOfClass:[NSDate class]]) {
        return [obj description];
    }
    
    FTInnerLogWarning(@"property values should be valid json types, but current value: %@, with invalid type: %@", obj, [obj class]);
    return [obj description];
}
@end
