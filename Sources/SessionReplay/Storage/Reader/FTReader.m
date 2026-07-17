//
//  FTReader.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/26.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTReader.h"
#import "FTTLV.h"
@implementation FTBatch
-(instancetype)initWithFile:(id<FTReadableFile>)file datas:(NSArray<FTTLV*> *)datas{
    self = [super init];
    if(self){
        _file = file;
        _tlvDatas = datas;
    }
    return self;
}
- (NSArray *)events{
    NSMutableArray *arrays = [[NSMutableArray alloc]init];
    for (FTTLV *tlv in self.tlvDatas) {
        [arrays addObject:tlv.value];
    }
    return arrays;
}
- (NSData *)serialize{
    NSMutableData *data = [[NSMutableData alloc]init];
    for (FTTLV *tlv in self.tlvDatas) {
        [data appendData:[tlv serialize]];
    }
    return data;
}
@end

#endif
