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
#import "FTDateUtil.h"
#import "FTJSONUtil.h"
#import "FTLog.h"

NSString * const FT_DATA_TYPE_RUM = @"RUM";
NSString * const FT_DATA_TYPE_LOGGING = @"Logging";
NSString * const FT_DATA_TYPE_TRACING = @"Tracing";
NSString * const FT_DATA_TYPE_OBJECT = @"Object";

@implementation FTRecordModel
-(instancetype)init{
    self = [super init];
    if (self) {
        _tm = [FTDateUtil currentTimeNanosecond];
        _op = @"";
    }
    return self;
}
-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm{
    self = [super init];
    if (self) {
        NSMutableDictionary *fieldDict = [NSMutableDictionary new];
        NSMutableDictionary *tagsDict = [NSMutableDictionary new];
        [fieldDict addEntriesFromDictionary:field];
        [tagsDict addEntriesFromDictionary:tags];
        NSMutableDictionary *opdata = @{
            @"source":source,
            @"field":fieldDict,
        }.mutableCopy;
        [opdata setValue:tagsDict forKey:@"tags"];
        NSDictionary *data =@{@"op":op,
                              @"opdata":opdata,
        };
        ZYDebug(@"write data = %@",data);
        _op = op;
        _data =[FTJSONUtil convertToJsonData:data];
        if (tm&&tm>0) {
            _tm = tm;
        }else{
            _tm = [FTDateUtil currentTimeNanosecond];
        }
    }
    return self;
}
@end
