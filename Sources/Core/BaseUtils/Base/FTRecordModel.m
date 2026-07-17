//
//  FTRecordModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2019/11/28.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTRecordModel.h"
#import "NSDate+FTUtil.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "FTConstants.h"
#import "NSDictionary+FTCopyProperties.h"

@implementation FTRecordModel
-(instancetype)init{
    self = [super init];
    if (self) {
        _tm = [NSDate ft_currentNanosecondTimeStamp];
        _op = @"";
        _remoteFilterChecked = NO;
    }
    return self;
}
-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    self = [super init];
    if (self) {
        NSDictionary *safeTags = [NSObject ft_normalizedDictionaryWithObject:tags];
        NSDictionary *safeFields = [NSObject ft_normalizedDictionaryWithObject:fields];
        if (source && op) {
            NSDictionary *opData = @{
                FT_KEY_SOURCE:source,
                FT_FIELDS:safeFields,
                FT_TAGS:safeTags,
                FT_TIME:@(tm)
            };
            NSDictionary *data =@{FT_OP:op,
                                  FT_OPDATA:opData,
            };
            NSString *jsonData = [FTJSONUtil convertToJsonData:data];
            if (!jsonData) {
                return nil;
            }
            _op = op;
            _data = jsonData;
            _tm = tm;
            _remoteFilterChecked = NO;
            FTInnerLogDebug(@"write data = %@",data);
            return self;
        }
    }
    return nil;
}
@end
