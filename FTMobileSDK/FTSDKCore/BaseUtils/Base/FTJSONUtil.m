//
//  FTJSONUtil.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
#import "FTJsonWriter.h"
@interface FTJSONUtil ()<FTJsonWriterDelegate>
@property (nonatomic, copy) NSString *error;
@property (nonatomic, strong) NSMutableData *acc;
@end
@implementation FTJSONUtil

/**
 *  @abstract
 *  把一个Object转成JsonData
 *
 *  @param obj 要转化的字典对象Object
 *
 *  @return 转化后得到的DATA
 */
- (NSData *)JSONSerializeDictObject:(NSDictionary *)obj {
    self.error = nil;

    self.acc = [[NSMutableData alloc] initWithCapacity:8096u];

    FTJsonWriter *streamWriter = [FTJsonWriter writerWithDelegate:self];

    if ([streamWriter writeObject:obj])
        return self.acc;

    self.error = streamWriter.error;
    return nil;
}

- (void)writer:(FTJsonWriter *)writer appendBytes:(const void *)bytes length:(NSUInteger)length {
    [self.acc appendBytes:bytes length:length];
}
+ (NSString *)convertToJsonData:(NSDictionary *)dict{
    NSString *result = nil;
    @try {
        FTJSONUtil *util = [FTJSONUtil new];
        NSData *jsonData = [util JSONSerializeDictObject:dict];
        if (jsonData) {
            result = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ exception encoding api data: %@", self, exception);
    }
    return result;
}
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString{
    NSDictionary *result = nil;
    @try {
        if (jsonString == nil) {
            return nil;
        }
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *err;
        result = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:NSJSONReadingMutableContainers
                                                   error:&err];
        if(err){
            FTInnerLogError(@"json解析失败：%@",err);
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
            FTInnerLogError(@"json 解析失败：%@",err);
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
    //防止 NaN 与 无穷大
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
