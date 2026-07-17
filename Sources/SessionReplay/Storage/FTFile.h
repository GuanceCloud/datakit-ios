//
//  FTFile.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/21.
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
@protocol FTFileProtocol <NSObject>
@property (nonatomic, strong) NSURL *url;
- (NSDate *)modifiedAt;
@end

@protocol  FTReadableFile <NSObject>
@property (nonatomic, copy) NSString *name;
- (NSInputStream *)stream;
- (void)deleteFile;
@end

@protocol FTWritableFile <NSObject>
@property (nonatomic, copy) NSString *name;

- (long long)size;
- (void)append:(NSData *)data;

@end

@interface FTFile : NSObject<FTReadableFile,FTWritableFile>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *fileCreationDate;
-(instancetype)initWithUrl:(NSURL *)url;
- (void)write:(NSData *)data;
@end

NS_ASSUME_NONNULL_END

#endif
