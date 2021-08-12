//
//  FTRecordModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import "FTDateUtil.h"
#import "FTJSONUtil.h"
#import "FTLog.h"
@implementation FTRecordModel
-(instancetype)init{
    self = [super init];
    if (self) {
        _tm = [FTDateUtil currentTimeNanosecond];
        _sessionid = [FTBaseInfoHander sessionId];
        _op = @"";
    }
    return self;
}
-(instancetype)initWithMeasurement:(NSString *)measurement op:(FTDataType )op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    self = [super init];
    if (self) {
        NSMutableDictionary *fieldDict = [NSMutableDictionary new];
        NSMutableDictionary *tagsDict = [NSMutableDictionary new];
        [fieldDict addEntriesFromDictionary:field];
        [tagsDict addEntriesFromDictionary:tags];
        NSString *opStr,*key;
        switch (op) {
            case FTDataTypeRUM:
                opStr = FT_DATA_TYPE_RUM;
                key = FT_AGENT_MEASUREMENT;
                break;
            case FTDataTypeLOGGING:
                key = FT_KEY_SOURCE;
                opStr = FT_DATA_TYPE_LOGGING;
                break;
            case FTDataTypeTRACING:
                key = FT_KEY_SOURCE;
                opStr = FT_DATA_TYPE_TRACING;
                break;
        }
        NSMutableDictionary *opdata = @{
            key:measurement,
            FT_AGENT_FIELD:fieldDict,
        }.mutableCopy;
        [opdata setValue:tagsDict forKey:FT_AGENT_TAGS];
        NSDictionary *data =@{@"op":opStr,
                              FT_AGENT_OPDATA:opdata,
        };
        ZYDebug(@"write data = %@",data);
        _op = opStr;
        _data =[FTJSONUtil convertToJsonData:data];
        if (tm&&tm>0) {
            _tm = tm;
        }
    }
    return self;
}
@end
