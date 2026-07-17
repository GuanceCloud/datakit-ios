//
//  FTReader.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTTLV;
@protocol FTReadableFile;

@interface FTBatch : NSObject
@property (nonatomic, strong) NSArray<FTTLV*> *tlvDatas;
@property (nonatomic, strong) id<FTReadableFile> file;
-(instancetype)initWithFile:(id<FTReadableFile>)file datas:(NSArray<FTTLV*> *)datas;
- (NSArray *)events;
- (NSData *)serialize;
@end
@protocol FTReader <NSObject>
- (NSArray<id<FTReadableFile>>*)readFiles:(int)limit;
- (nullable FTBatch*)readBatch:(id<FTReadableFile>)file;
- (void)markBatchAsRead:(FTBatch*)batch;
   
@end

NS_ASSUME_NONNULL_END

#endif
