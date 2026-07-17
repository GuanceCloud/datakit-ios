//
//  FTDataStore.h
//  SessionReplay
//
//  Created by hulilei on 2024/7/1.
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

#ifndef FTDataStore_h
#define FTDataStore_h
typedef uint16_t FTDataStoreKeyVersion;

// Saved data, when data structure changes, update this constant to distinguish between old and new data, can be compatible with old data or directly delete
static FTDataStoreKeyVersion const DataStoreDefaultKeyVersion = 0;

typedef NS_ENUM(uint16_t,DataStoreBlockType) {
    DataStoreBlockTypeVersion = 0x00,
    DataStoreBlockTypeData = 0X01,
};

typedef void (^DataStoreValueResult)(NSError *error,NSData *data,FTDataStoreKeyVersion version);
@protocol FTDataStore <NSObject>
- (void)setValue:(NSData*)value forKey:(NSString *)key version:(FTDataStoreKeyVersion)version;
- (void)removeValueForKey:(NSString *)key;
- (void)valueForKey:(NSString *)key callback:(DataStoreValueResult)callback;
@end

#endif /* FTDataStore_h */

#endif
