//
//  FTRequestBody.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequestBody.h"
#import "FTLog.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
typedef NS_OPTIONS(NSInteger, FTParameterType) {
    FTParameterTypetTag      = 1,
    FTParameterTypeField     = 2 ,
};
@interface FTQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) NSString *field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;
- (NSString *)URLEncodedTagsStringValue;
- (NSString *)URLEncodedFiledStringValue;
@end
@implementation FTQueryStringPair
- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    _field = field;
    _value = value;
    return self;
}
- (NSString *)URLEncodedTagsStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [NSString stringWithFormat:@"%@=%@", [self repleacingSpecialCharacters:self.field],@""];
    } else {
        return [NSString stringWithFormat:@"%@=%@", [self repleacingSpecialCharacters:self.field], [self repleacingSpecialCharacters:self.value]];
    }
}
- (NSString *)URLEncodedFiledStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [NSString stringWithFormat:@"%@=%@", [self repleacingSpecialCharacters:self.field],@"NULL"];
    }else{
        if([self.value isKindOfClass:NSString.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [self repleacingSpecialCharacters:self.field], [self repleacingSpecialCharactersField:self.value]];
        }else if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            if (strcmp([number objCType], @encode(float)) == 0||strcmp([number objCType], @encode(double)) == 0)
            {
                return  [NSString stringWithFormat:@"%@=%.1f", [self repleacingSpecialCharacters:self.field], number.floatValue];
            }
        }
        return [NSString stringWithFormat:@"%@=%@i", [self repleacingSpecialCharacters:self.field], self.value];
    }
}
- (id)repleacingSpecialCharacters:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@"=" withString:@"\\="];
        reStr =[reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        return reStr;
    }else{
        return str;
    }
    
}
- (id)repleacingSpecialCharactersField:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        reStr = [reStr stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        return reStr;
    }else{
        return str;
    }
    
}
NSString * FTQueryStringFromParameters(NSDictionary *parameters,FTParameterType type) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(nil,parameters,type)) {
        if (type == FTParameterTypeField) {
            [mutablePairs addObject:[pair URLEncodedFiledStringValue]];
        }else{
            [mutablePairs addObject:[pair URLEncodedTagsStringValue]];
        }
    }
    return [mutablePairs componentsJoinedByString:@","];
}
NSArray * FTQueryStringPairsFromKeyAndValue(NSString *key, id value,FTParameterType type) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:FTQueryStringPairsFromKeyAndValue( nestedKey, nestedValue,type)];
            }
        }
    }else{
        [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:key value:value]];
    }
    return mutableQueryStringComponents;
}
@end

@implementation FTRequestBody : NSObject

+ (id )repleacingSpecialCharactersMeasurement:(NSString *)str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        reStr = [reStr stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        return reStr;
    }else{
        return str;
    }
}

@end
@implementation FTRequestLineBody
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *field = @"";
        NSDictionary *opdata =item[@"opdata"];
        
        NSString *source =[FTRequestBody repleacingSpecialCharactersMeasurement:[opdata valueForKey:@"source"]];
        if (!source) {
            source =[FTRequestBody repleacingSpecialCharactersMeasurement:[opdata valueForKey:@"measurement"]];
        }
        NSDictionary *tagDict = opdata[@"tags"];
        if ([[opdata allKeys] containsObject:@"field"]) {
            field=FTQueryStringFromParameters(opdata[@"field"],FTParameterTypeField);
        }
        NSString *tagsStr = tagDict.allKeys.count>0 ? FTQueryStringFromParameters(tagDict,FTParameterTypetTag):nil;
      
        NSString *requestStr = tagsStr.length>0? [NSString stringWithFormat:@"%@,%@ %@ %lld",source,tagsStr,field,obj.tm]:[NSString stringWithFormat:@"%@ %@ %lld",source,field,obj.tm];
        if (idx==0) {
            [requestDatas appendString:requestStr];
        }else{
            [requestDatas appendFormat:@"\n%@",requestStr];
        }
    }];
    FTRecordModel *model = [events firstObject];
    ZYDebug(@"\nUpload Datas Type:%@\nLine RequestDatas:\n%@",model.op,requestDatas);
    return requestDatas;
}
@end
@implementation FTRequestObjectBody
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events{
    NSMutableArray *list = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:obj.data].mutableCopy;
        [list addObject:item];
    }];
    // 待处理 object 类型
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:list options:NSJSONWritingPrettyPrinted error:&error];
    NSString *requestData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    ZYLog(@"requestData = %@",requestData);
    return  requestData;
}
@end
