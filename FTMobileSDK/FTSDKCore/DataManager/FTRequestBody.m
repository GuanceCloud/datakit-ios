//
//  FTRequestBody.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequestBody.h"
#import "FTLog+Private.h"
#import "FTRecordModel.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "NSNumber+FTAdd.h"
#import "NSString+FTAdd.h"
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
- (NSString *)URLEncodedFiledStringValueWithIntegerCompatible:(BOOL)compatible;
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
        return [NSString stringWithFormat:@"%@=%@", [self.field ft_replacingSpecialCharacters], number.ft_toTagFormat];
    }else if([self.value isKindOfClass:NSString.class]){
        return [NSString stringWithFormat:@"%@=%@", [self.field ft_replacingSpecialCharacters], [self.value ft_replacingSpecialCharacters]];
    }else{
        NSString *str = [[FTJSONUtil convertToJsonDataWithObject:self.value] ft_replacingSpecialCharacters];
        if(str && str.length>0){
            return [NSString stringWithFormat:@"%@=%@", [self.field ft_replacingSpecialCharacters], str];
        }else{
            return nil;
        }
    }
}
- (NSString *)URLEncodedFiledStringValueWithIntegerCompatible:(BOOL)compatible{
    if (!self.value || [self.value isEqual:[NSNull null]] || ([self.value isKindOfClass:NSString.class] && [self.value isEqualToString: @""])) {
        return [NSString stringWithFormat:@"%@=\"\"",[self.field ft_replacingSpecialCharacters]];
    }else{
        if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            return  [NSString stringWithFormat:@"%@=%@", [self.field ft_replacingSpecialCharacters], compatible?number.ft_toFieldIntegerCompatibleFormat:number.ft_toFieldFormat];
        }else if ([self.value isKindOfClass:NSString.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [self.field ft_replacingSpecialCharacters], [self.value ft_replacingFieldSpecialCharacters]];
        }else{
            NSString *str = [[FTJSONUtil convertToJsonDataWithObject:self.value] ft_replacingFieldSpecialCharacters];
            if(str){
                return [NSString stringWithFormat:@"%@=\"%@\"", [self.field ft_replacingSpecialCharacters], str];
            }else{
                return [NSString stringWithFormat:@"%@=\"\"",[self.field ft_replacingSpecialCharacters]];
            }
        }
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
NSString * FTQueryStringFromParameters(NSDictionary *parameters,FTParameterType type,BOOL compatible) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(parameters)) {
        if (type == FTParameterTypeField) {
            [mutablePairs addObject:[pair URLEncodedFiledStringValueWithIntegerCompatible:compatible]];
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

@end
@implementation FTRequestLineBody
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events packageId:(NSString *)packageId enableIntegerCompatible:(BOOL)compatible{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata =item[FT_OPDATA];
        NSString *source = [[opdata valueForKey:FT_KEY_SOURCE] ft_replacingMeasurementSpecialCharacters];
        if (!source) {
            source =[[opdata valueForKey:FT_MEASUREMENT] ft_replacingMeasurementSpecialCharacters];
        }
        NSDictionary *tag = opdata[FT_TAGS];
        NSDictionary *field = opdata[FT_FIELDS];
        if(source.length>0 && field.count>0 && tag.count>0){
            NSString *dataId = [NSString stringWithFormat:@"%@.%@",packageId,[FTBaseInfoHandler randomUUID]];
            NSMutableDictionary *tagDict = @{@"sdk_data_id":dataId}.mutableCopy;
            if(tag.allKeys.count>0){
                [tagDict addEntriesFromDictionary:tag];
            }
            NSString *tagStr = FTQueryStringFromParameters(tagDict,FTParameterTypeTag,compatible);
            NSString *fieldStr= FTQueryStringFromParameters(opdata[FT_FIELDS],FTParameterTypeField,compatible);
            
            NSString *requestStr = [NSString stringWithFormat:@"%@,%@ %@ %lld",source,tagStr,fieldStr,obj.tm];
            if (idx==0) {
                [requestDatas appendString:requestStr];
            }else{
                [requestDatas appendFormat:@"\n%@",requestStr];
            }
        }else{
            FTInnerLogError(@"\n*********此条数据格式错误********\n%@ %lld\n******************\n",item,obj.tm);
        }
    }];
    FTRecordModel *model = [events firstObject];
    FTInnerLogDebug(@"\nUpload Datas Type:%@\nLine RequestDatas:\n%@",model.op,requestDatas);
    return requestDatas;
}
@end
