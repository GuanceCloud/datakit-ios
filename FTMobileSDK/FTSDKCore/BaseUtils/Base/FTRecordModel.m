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
#import "NSDate+FTUtil.h"
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
#import "FTConstants.h"
@implementation FTRecordModel
-(instancetype)init{
    self = [super init];
    if (self) {
        _tm = [NSDate ft_currentNanosecondTimeStamp];
        _op = @"";
    }
    return self;
}
-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    self = [super init];
    if (self) {
        if (source && op && tags && fields) {
            NSDictionary *opData = @{
                FT_KEY_SOURCE:source,
                FT_FIELDS:fields,
                FT_TAGS:tags,
                FT_TIME:@(tm)
            };
            NSDictionary *data =@{FT_OP:op,
                                  FT_OPDATA:opData,
            };
            _op = op;
            _data = [FTJSONUtil convertToJsonData:data];
            _tm = tm;
            FTInnerLogDebug(@"write data = %@",data);
            return self;
        }
    }
    return nil;
}
@end
