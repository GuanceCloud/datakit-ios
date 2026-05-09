//
//  FTRequestBody.m
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequestBody.h"
#import "FTInnerLog.h"
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
@interface FTRequestLineBody ()
- (NSArray *)deduplicatedRumViewEvents:(NSArray *)events;
- (NSString *)rumViewIdForEvent:(FTRecordModel *)event;
@end
@implementation FTRequestLineBody
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events packageId:(NSString *)packageId enableIntegerCompatible:(BOOL)compatible{
    __block NSMutableString *requestDatas = [NSMutableString new];
    NSArray *eventsSnapshot = [events copy];
    FTRecordModel *model = [eventsSnapshot firstObject];
    if ([model.op isEqualToString:FT_DATA_TYPE_RUM]) {
        eventsSnapshot = [self deduplicatedRumViewEvents:eventsSnapshot];
    }
    [eventsSnapshot enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        @autoreleasepool {
            NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:obj.data];
            if (!item) {
                FTInnerLogError(@"\n*********This data format is incorrect********\n%@\n******************\n",obj.data);
                return;
             }
            NSDictionary *opdata =item[FT_OPDATA];
            NSString *sourceRaw = opdata[FT_KEY_SOURCE]?:opdata[FT_MEASUREMENT];
            NSString *source =[sourceRaw ft_replacingMeasurementSpecialCharacters];
            
            NSDictionary *tag = opdata[FT_TAGS];
            NSDictionary *field = opdata[FT_FIELDS];
            NSNumber *timeNum = opdata[FT_TIME];
            long long time = timeNum == nil ? obj.tm : [timeNum longLongValue];
            
            if(source.length>0 && field.count>0 && tag.count>0){
                NSString *dataId = [NSString stringWithFormat:@"%@.%@",packageId,[FTBaseInfoHandler random16UUID]];
                NSMutableDictionary *tagDict = [NSMutableDictionary dictionary];
                [tagDict setValue:dataId forKey:@"sdk_data_id"];
                [tagDict addEntriesFromDictionary:tag];
                NSString *tagStr = FTQueryStringFromParameters(tagDict,FTParameterTypeTag,compatible);
                NSString *fieldStr= FTQueryStringFromParameters(opdata[FT_FIELDS],FTParameterTypeField,compatible);
                NSString *requestStr = [NSString stringWithFormat:@"%@,%@ %@ %lld",source,tagStr,fieldStr,time];
                if (requestDatas.length == 0) {
                    [requestDatas appendString:requestStr];
                }else{
                    [requestDatas appendFormat:@"\n%@",requestStr];
                }
            }else{
                FTInnerLogError(@"\n*********This data format is incorrect********\n%@ %lld\n******************\n",item,time);
            }
        }
    }];
    FTInnerLogDebug(@"[NETWORK]\nUpload Datas Type:%@\nLine RequestDatas:\n%@",model.op,requestDatas);
    return [requestDatas copy];
}
- (NSArray *)deduplicatedRumViewEvents:(NSArray *)events{
    if (events.count <= 1) {
        return events;
    }
    NSMutableDictionary<NSString *, NSNumber *> *selectedIndexes = [NSMutableDictionary dictionary];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *viewId = [self rumViewIdForEvent:obj];
        if (viewId.length == 0) {
            return;
        }
        NSNumber *selectedIndex = selectedIndexes[viewId];
        if (!selectedIndex) {
            selectedIndexes[viewId] = @(idx);
            return;
        }
        FTRecordModel *selectedEvent = events[selectedIndex.unsignedIntegerValue];
        if (obj._id.longLongValue > selectedEvent._id.longLongValue) {
            selectedIndexes[viewId] = @(idx);
        }
    }];
    if (selectedIndexes.count == 0) {
        return events;
    }
    NSMutableArray *deduplicatedEvents = [NSMutableArray arrayWithCapacity:events.count];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *viewId = [self rumViewIdForEvent:obj];
        NSNumber *selectedIndex = viewId.length > 0 ? selectedIndexes[viewId] : nil;
        if (!selectedIndex || selectedIndex.unsignedIntegerValue == idx) {
            [deduplicatedEvents addObject:obj];
        }
    }];
    return [deduplicatedEvents copy];
}
- (NSString *)rumViewIdForEvent:(FTRecordModel *)event{
    if (![event.op isEqualToString:FT_DATA_TYPE_RUM]) {
        return nil;
    }
    NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:event.data];
    if (![item isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSDictionary *opdata = item[FT_OPDATA];
    if (![opdata isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *sourceRaw = opdata[FT_KEY_SOURCE]?:opdata[FT_MEASUREMENT];
    if (![sourceRaw isKindOfClass:NSString.class] || ![sourceRaw isEqualToString:FT_RUM_SOURCE_VIEW]) {
        return nil;
    }
    NSDictionary *tags = opdata[FT_TAGS];
    if (![tags isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *viewId = tags[FT_KEY_VIEW_ID];
    return [viewId isKindOfClass:NSString.class] ? viewId : nil;
}
@end
