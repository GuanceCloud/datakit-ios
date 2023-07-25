//
//  FTRequestBody.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequestBody.h"
#import "FTInternalLog.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
typedef NS_OPTIONS(NSInteger, FTParameterType) {
    FTParameterTypeTag      = 1,
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
    if (self) {
        _field = field;
        _value = value;
    }
    return self;
}
- (NSString *)URLEncodedTagsStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]] || ([self.value isKindOfClass:NSString.class] && [self.value isEqualToString: @""])) {
        return [NSString stringWithFormat:@"%@=NULL", [self replacingSpecialCharacters:self.field]];
    }else{
        return [NSString stringWithFormat:@"%@=%@", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharacters:self.value]];
    }
}
- (NSString *)URLEncodedFiledStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]] || ([self.value isKindOfClass:NSString.class] && [self.value isEqualToString: @""])) {
        return [NSString stringWithFormat:@"%@=\"%@\"",[self replacingSpecialCharacters:self.field],FT_NULL_VALUE];
    }else{
        if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            if (strcmp([number objCType], @encode(float)) == 0||strcmp([number objCType], @encode(double)) == 0)
            {
                return  [NSString stringWithFormat:@"%@=%.1f", [self replacingSpecialCharacters:self.field], number.floatValue];
            }else{
                return [NSString stringWithFormat:@"%@=%@i", [self replacingSpecialCharacters:self.field], self.value];
            }
        }else if ([self.value isKindOfClass:NSArray.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharactersField:[FTJSONUtil convertToJsonDataWithArray:self.value]]];
        }else if ([self.value isKindOfClass:NSDictionary.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharactersField:[FTJSONUtil convertToJsonData:self.value]]];

        }
        return [NSString stringWithFormat:@"%@=\"%@\"", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharactersField:self.value]];
    }
}
- (id)replacingSpecialCharacters:(id )str{
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
- (id)replacingSpecialCharactersField:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        reStr = [reStr stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        return reStr;
    }else{
        return str;
    }
    
}
NSArray * FTQueryStringPairsFromKeyAndValue(NSString *key, id value,FTParameterType type) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:nestedKey value:nestedValue]];
            }
        }
    }else{
        [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:key value:value]];
    }
    return mutableQueryStringComponents;
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
        NSDictionary *opdata =item[FT_OPDATA];
        
        NSString *source =[FTRequestBody repleacingSpecialCharactersMeasurement:[opdata valueForKey:FT_KEY_SOURCE]];
        if (!source) {
            source =[FTRequestBody repleacingSpecialCharactersMeasurement:[opdata valueForKey:FT_MEASUREMENT]];
        }
        NSDictionary *tagDict = opdata[FT_TAGS];
        NSString *tagsStr = tagDict.allKeys.count>0 ? FTQueryStringFromParameters(tagDict,FTParameterTypeTag):nil;
        if ([[opdata allKeys] containsObject:FT_FIELDS]) {
            NSString *field=FTQueryStringFromParameters(opdata[FT_FIELDS],FTParameterTypeField);
            
            NSString *requestStr = tagsStr.length>0? [NSString stringWithFormat:@"%@,%@ %@ %lld",source,tagsStr,field,obj.tm]:[NSString stringWithFormat:@"%@ %@ %lld",source,field,obj.tm];
            if (idx==0) {
                [requestDatas appendString:requestStr];
            }else{
                [requestDatas appendFormat:@"\n%@",requestStr];
            }
        }else{
            FTInnerLogError(@"\n*********此条数据格式错误********\n%@,%@  %lld\n******************\n",source,tagsStr,obj.tm);
        }
    }];
    FTRecordModel *model = [events firstObject];
    FTInnerLogDebug(@"\nUpload Datas Type:%@\nLine RequestDatas:\n%@",model.op,requestDatas);
    return requestDatas;
}
@end
