//
//  FTFeatureStorage.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFeatureStorage.h"
#import "FTFeatureDirectories.h"
#import "FTFilesOrchestrator.h"
#import "FTDirectory.h"
#import "FTPerformancePreset.h"
#import "FTFileWriter.h"
#import "FTDataReader.h"
#import "FTFileReader.h"
#import "FTSessionReplayCoreImports.h"
#import "FTTmpCacheManager.h"

static NSString * const FTWebViewFilePrefix = @"w";

@interface FTNoOpWriter : NSObject<FTWriter>
@end

@implementation FTNoOpWriter
- (void)write:(NSData *)datas {
}

- (void)write:(NSData *)datas forceNewFile:(BOOL)update {
}
@end

@interface FTFeatureStorage()
@property (nonatomic, copy) NSString *featureName;
@property (nonatomic, strong) FTFilesOrchestrator *authorizedFilesOrchestrator;
@property (nonatomic, strong, nullable) FTFilesOrchestrator *unauthorizedFilesOrchestrator;
@property (nonatomic, strong, nullable) FTFilesOrchestrator *cacheAuthorizedFilesOrchestrator;
@property (nonatomic, strong) FTFilesOrchestrator *webAuthorizedFilesOrchestrator;
@property (nonatomic, strong, nullable) FTFilesOrchestrator *webUnauthorizedFilesOrchestrator;
@property (nonatomic, strong, nullable) FTFilesOrchestrator *webCacheAuthorizedFilesOrchestrator;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) FTFeatureDirectories *directories;
@property (nonatomic, strong) id<FTWriter> authorizedWriter;
@property (nonatomic, strong) id<FTWriter> pendingWriter;
@property (nonatomic, strong, nullable) id<FTCacheWriter> cacheWriter;
@property (nonatomic, strong) id<FTWriter> webViewAuthorizedWriter;
@property (nonatomic, strong) id<FTWriter> webViewPendingWriter;
@property (nonatomic, strong) id<FTWriter> webViewCacheWriter;
@property (nonatomic, strong) id<FTWriter> noOpWriter;
@property (nonatomic, assign) BOOL cacheWriterActive;
@end
@implementation FTFeatureStorage

-(instancetype)initWithFeatureName:(NSString *)featureName
                             queue:(dispatch_queue_t)queue
                       directories:(FTFeatureDirectories *)directories
                       performance:(FTPerformancePreset *)performance{
    self = [super init];
    if(self){
        _featureName = featureName;
        _queue = queue;
        _performance = performance;
        _directories = directories;
        _noOpWriter = [[FTNoOpWriter alloc]init];
        _authorizedFilesOrchestrator = [self orchestratorForDirectory:directories.granted];
        _unauthorizedFilesOrchestrator = [self orchestratorForDirectory:directories.pending];
        _cacheAuthorizedFilesOrchestrator = [self orchestratorForDirectory:directories.errorSampled];
        // WebView records share the native record directories. Keep the "w" file prefix
        // to avoid same-millisecond native/web file collisions and preserve web file identity.
        _webAuthorizedFilesOrchestrator = [self orchestratorForDirectory:directories.granted prefix:FTWebViewFilePrefix];
        _webUnauthorizedFilesOrchestrator = [self orchestratorForDirectory:directories.pending prefix:FTWebViewFilePrefix];
        _webCacheAuthorizedFilesOrchestrator = [self orchestratorForDirectory:directories.errorSampled prefix:FTWebViewFilePrefix];
        _authorizedWriter = [self fileWriterForOrchestrator:_authorizedFilesOrchestrator] ?: _noOpWriter;
        _pendingWriter = [self fileWriterForOrchestrator:_unauthorizedFilesOrchestrator] ?: _noOpWriter;
        if (_cacheAuthorizedFilesOrchestrator) {
            id<FTWriter> cacheFileWriter = [self fileWriterForOrchestrator:_cacheAuthorizedFilesOrchestrator];
            _cacheWriter = [[FTTmpCacheManager alloc]initWithCacheFileWriter:cacheFileWriter
                                                              cacheDirectory:directories.errorSampled
                                                                    directory:directories.granted
                                                                        queue:queue];
        }
        _webViewAuthorizedWriter = [self fileWriterForOrchestrator:_webAuthorizedFilesOrchestrator] ?: _noOpWriter;
        _webViewPendingWriter = [self fileWriterForOrchestrator:_webUnauthorizedFilesOrchestrator] ?: _noOpWriter;
        _webViewCacheWriter = [self fileWriterForOrchestrator:_webCacheAuthorizedFilesOrchestrator] ?: _noOpWriter;
    }
    return self;
}
- (id<FTWriter>)writer{
    return self.authorizedWriter;
}
- (id<FTWriter>)webViewWriter{
    return self.webViewAuthorizedWriter;
}
- (void)updateTrackingConsent:(FTTrackingConsent)trackingConsent{
    BOOL shouldActivateCacheWriter = trackingConsent == FTTrackingConsentErrorSampled;
    @synchronized (self) {
        if (_cacheWriterActive == shouldActivateCacheWriter) {
            return;
        }
        _cacheWriterActive = shouldActivateCacheWriter;
    }
    id<FTCacheWriter> cacheWriter = self.cacheWriter;
    if (!cacheWriter) {
        return;
    }
    if(shouldActivateCacheWriter){
        [cacheWriter active];
    }else{
        [cacheWriter inactive];
    }
}
- (id<FTWriter>)writerForTrackingConsent:(FTTrackingConsent)trackingConsent{
    [self updateTrackingConsent:trackingConsent];
    switch (trackingConsent) {
        case FTTrackingConsentGranted:
            return self.authorizedWriter;
        case FTTrackingConsentNotGranted:
            return self.noOpWriter;
        case FTTrackingConsentPending:
            return self.pendingWriter;
        case FTTrackingConsentErrorSampled:
            return self.cacheWriter ?: self.noOpWriter;
    }
}
- (id<FTWriter>)webViewWriterForTrackingConsent:(FTTrackingConsent)trackingConsent{
    [self updateTrackingConsent:trackingConsent];
    switch (trackingConsent) {
        case FTTrackingConsentGranted:
            return self.webViewAuthorizedWriter;
        case FTTrackingConsentNotGranted:
            return self.noOpWriter;
        case FTTrackingConsentPending:
            return self.webViewPendingWriter;
        case FTTrackingConsentErrorSampled:
            return self.webViewCacheWriter;
    }
}
- (FTFilesOrchestrator *)orchestratorForDirectory:(FTDirectory *)directory{
    return [self orchestratorForDirectory:directory prefix:nil];
}
- (FTFilesOrchestrator *)orchestratorForDirectory:(FTDirectory *)directory prefix:(NSString *)prefix{
    if (!directory) {
        return nil;
    }
    if (prefix.length > 0) {
        return [[FTFilesOrchestrator alloc]initWithDirectory:directory
                                                 performance:self.performance
                                                      prefix:prefix];
    }
    return [[FTFilesOrchestrator alloc]initWithDirectory:directory performance:self.performance];
}
- (void)performStorageOperation:(void(^)(void))operation failureMessage:(NSString *)failureMessage{
    dispatch_async(self.queue, ^{
        @try {
            if (operation) {
                operation();
            }
        }
        @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] %@ in %@: %@", failureMessage, self.featureName, exception.description);
        }
    });
}
- (id<FTWriter>)fileWriterForOrchestrator:(FTFilesOrchestrator *)orchestrator{
    if (!orchestrator) {
        return nil;
    }
    return [[FTFileWriter alloc]initWithOrchestrator:orchestrator queue:self.queue];
}
- (void)migrateUnauthorizedDataToConsent:(FTTrackingConsent)trackingConsent{
    [self performStorageOperation:^{
        switch (trackingConsent) {
            case FTTrackingConsentGranted:
                [self.directories.pending moveAllFilesToDestinationDirectory:self.directories.granted];
                break;
            case FTTrackingConsentNotGranted:
                [self.directories.pending deleteAllFiles];
                break;
            case FTTrackingConsentPending:
            case FTTrackingConsentErrorSampled:
                break;
        }
    } failureMessage:@"Failed to migrate unauthorized data"];
}
- (void)clearUnauthorizedData{
    [self performStorageOperation:^{
        [self.directories.pending deleteAllFiles];
    } failureMessage:@"Failed to clear unauthorized data"];
}
- (void)clearAllData{
    [self performStorageOperation:^{
        [self.directories.pending deleteAllFiles];
        [self.directories.granted deleteAllFiles];
        [self.directories.errorSampled deleteAllFiles];
    } failureMessage:@"Failed to clear all data"];
}
- (void)setIgnoreFilesAgeWhenReading:(BOOL)ignore{
    dispatch_sync(self.queue, ^{
        self.authorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
        self.unauthorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
        self.cacheAuthorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
        self.webAuthorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
        self.webUnauthorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
        self.webCacheAuthorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
    });
}
- (id<FTReader>)reader {
    FTDataReader *reader = [[FTDataReader alloc]
                            initWithQueue:self.queue
                            fileReader:[[FTFileReader alloc] initWithOrchestrator:self.authorizedFilesOrchestrator]];
    return reader;
}

@end
