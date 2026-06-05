//
//  FTDataStorage.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

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
