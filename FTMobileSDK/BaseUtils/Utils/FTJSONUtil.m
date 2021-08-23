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
#import "FTLog.h"
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
+ (NSString *)convertToJsonData:(NSDictionary *)dict
{
    FTJSONUtil *util = [FTJSONUtil new];
    NSData *jsonData = [util JSONSerializeDictObject:dict];
    NSString *jsonString;
    if (jsonData) {
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    return mutStr;
}
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        ZYErrorLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

@end
