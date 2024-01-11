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
#import "NSNumber+FTAdd.h"
#import "FTBaseInfoHandler.h"
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
        return nil;
    }else if([self.value isKindOfClass:NSNumber.class]){
        NSNumber *number = self.value;
        return [NSString stringWithFormat:@"%@=%@", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharacters:number.ft_toTagFormat]];
    }else{
        return [NSString stringWithFormat:@"%@=%@", [self replacingSpecialCharacters:self.field], [self replacingSpecialCharacters:self.value]];
    }
}
- (NSString *)URLEncodedFiledStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]] || ([self.value isKindOfClass:NSString.class] && [self.value isEqualToString: @""])) {
        return [NSString stringWithFormat:@"%@=\"\"",[self replacingSpecialCharacters:self.field]];
    }else{
        if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            return  [NSString stringWithFormat:@"%@=%@", [self replacingSpecialCharacters:self.field], number.ft_toFiledString];
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
NSArray * FTQueryStringPairsFromKeyAndValue(NSDictionary *value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:nestedKey value:nestedValue]];
            }
        }
    }
    return mutableQueryStringComponents;
}
NSString * FTQueryStringFromParameters(NSDictionary *parameters,FTParameterType type) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(parameters)) {
        if (type == FTParameterTypeField) {
            [mutablePairs addObject:[pair URLEncodedFiledStringValue]];
        }else{
            NSString *str = [pair URLEncodedTagsStringValue];
            if(str){
                [mutablePairs addObject:str];
            }
           
        }
    }
    return [mutablePairs componentsJoinedByString:@","];
}
@end

@implementation FTRequestBody : NSObject

+ (id )replacingSpecialCharactersMeasurement:(NSString *)str{
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
        
        NSString *source =[FTRequestBody replacingSpecialCharactersMeasurement:[opdata valueForKey:FT_KEY_SOURCE]];
        if (!source) {
            source =[FTRequestBody replacingSpecialCharactersMeasurement:[opdata valueForKey:FT_MEASUREMENT]];
        }
        NSMutableDictionary *tagDict = @{@"sdk_data_id":[FTBaseInfoHandler randomUUID]}.mutableCopy;
        NSDictionary *tag = opdata[FT_TAGS];
        
        if(tag.allKeys.count>0){
            [tagDict addEntriesFromDictionary:tag];
        }
        NSString *tagStr = FTQueryStringFromParameters(tagDict,FTParameterTypeTag);

        if ([[opdata allKeys] containsObject:FT_FIELDS]) {
            NSString *field=FTQueryStringFromParameters(opdata[FT_FIELDS],FTParameterTypeField);
            
            NSString *requestStr = tagStr.length>0? [NSString stringWithFormat:@"%@,%@ %@ %lld",source,tagStr,field,obj.tm]:[NSString stringWithFormat:@"%@ %@ %lld",source,field,obj.tm];
            if (idx==0) {
                [requestDatas appendString:requestStr];
            }else{
                [requestDatas appendFormat:@"\n%@",requestStr];
            }
        }else{
            FTInnerLogError(@"\n*********此条数据格式错误********\n%@,%@  %lld\n******************\n",source,tagStr,obj.tm);
        }
    }];
    FTRecordModel *model = [events firstObject];
    FTInnerLogDebug(@"\nUpload Datas Type:%@\nLine RequestDatas:\n%@",model.op,requestDatas);
    return requestDatas;
}
@end
