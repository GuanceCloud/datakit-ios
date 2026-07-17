//
//  FTFeatureStorage.h
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
@class FTPerformancePreset,FTDirectory,FTFeatureDirectories;
NS_ASSUME_NONNULL_BEGIN
@protocol FTWriter,FTReader,FTCacheWriter;
typedef NS_ENUM(NSInteger, FTTrackingConsent) {
    FTTrackingConsentGranted,
    FTTrackingConsentNotGranted,
    FTTrackingConsentPending,
    FTTrackingConsentErrorSampled,
};
@interface FTFeatureStorage : NSObject
-(instancetype)initWithFeatureName:(NSString *)featureName
                             queue:(dispatch_queue_t)queue
                       directories:(FTFeatureDirectories *)directories
                       performance:(FTPerformancePreset *)performance;

- (void)updateTrackingConsent:(FTTrackingConsent)trackingConsent;
- (id<FTWriter>)writerForTrackingConsent:(FTTrackingConsent)trackingConsent NS_SWIFT_NAME(writer(for:));
- (id<FTWriter>)webViewWriterForTrackingConsent:(FTTrackingConsent)trackingConsent NS_SWIFT_NAME(webViewWriter(for:));
- (id<FTReader>)reader;
- (nullable id<FTCacheWriter>)cacheWriter;
- (void)migrateUnauthorizedDataToConsent:(FTTrackingConsent)trackingConsent;
- (void)clearUnauthorizedData;
- (void)clearAllData;
- (void)setIgnoreFilesAgeWhenReading:(BOOL)ignore;
@end

NS_ASSUME_NONNULL_END

#endif
