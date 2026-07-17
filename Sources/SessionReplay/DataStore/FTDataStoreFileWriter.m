//
//  FTDataStoreFileWriter.m
//  SessionReplay
//
//  Created by hulilei on 2024/7/2.
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

#import "FTDataStoreFileWriter.h"
#import "FTFile.h"
#import "FTDataStore.h"
#import "FTTLV.h"
@interface FTDataStoreFileWriter()
@property (nonatomic, strong) FTFile *file;
@end
@implementation FTDataStoreFileWriter
-(instancetype)initWithFile:(FTFile *)file{
    self = [super init];
    if(self){
        _file = file;
    }
    return self;
}
- (void)write:(NSData *)data version:(FTDataStoreKeyVersion)version{
    NSData *typeData = [NSData dataWithBytes:&version length:sizeof(version)];
    FTTLV *versionTLV = [[FTTLV alloc]initWithType:DataStoreBlockTypeVersion value:typeData];
    FTTLV *dataTLV = [[FTTLV alloc]initWithType:DataStoreBlockTypeData value:data];
    NSMutableData *encoded = [[NSMutableData alloc]init];
    NSData *versionSerialize = [versionTLV serialize:sizeof(FTDataStoreKeyVersion)];
    if(versionSerialize){
        [encoded appendData:versionSerialize];
    }else{
        return;
    }
    NSData *dataSerialize = [dataTLV serialize];
    if(dataSerialize){
        [encoded appendData:dataSerialize];
    }else{
        return;
    }
    [self.file write:encoded];
}
@end

#endif
