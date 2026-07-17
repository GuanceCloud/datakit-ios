//
//  FTRumSessionReplay.m
//  SessionReplay
//
//  Created by hulilei on 2022/12/23.
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

#import "FTRumSessionReplay.h"
#import "FTResourcesFeature.h"
#import "FTFeatureUpload.h"
#import "FTFileWriter.h"
#import "FTPerformancePreset.h"
#import "FTFeatureStorage.h"
#import "FTCoreDirectory.h"
#import "FTSessionReplayFeature.h"
#import "FTFeatureDataStore.h"
#import "FTTmpCacheManager.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTSessionReplayCoreImports.h"
#import "FTWKWebViewHandler+SessionReplay.h"

@interface FTFeatureStores : NSObject
@property (nonatomic, strong) FTFeatureStorage *storage;
@property (nonatomic, strong) FTFeatureUpload *upload;
-(instancetype)initWithStorage:(FTFeatureStorage *)storage upload:(FTFeatureUpload *)upload;
@end
@implementation FTFeatureStores
-(instancetype)initWithStorage:(FTFeatureStorage *)storage upload:(FTFeatureUpload *)upload{
    self = [super init];
    if(self){
        _storage = storage;
        _upload = upload;
    }
    return self;
}
@end
@interface FTRumSessionReplay ()
@property (nonatomic, strong) dispatch_queue_t readWriteQueue;
@property (nonatomic, strong) FTCoreDirectory *coreDirectory;
@property (nonatomic, strong) FTPerformancePreset *performancePreset;
@property (nonatomic, strong) NSMutableDictionary<NSString*,FTFeatureStores*>*stores;
@property (nonatomic, strong) NSMutableDictionary<NSString*,id<FTRemoteFeature>>*features;
@property (nonatomic, copy) NSString *source;
@end
@implementation FTRumSessionReplay
static FTRumSessionReplay *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _coreDirectory = [[FTCoreDirectory alloc]initWithSubdirectoryPath:@"com.ft"];
        _readWriteQueue = dispatch_queue_create("com.ft.file.readwrite", 0);
        _performancePreset = [[FTPerformancePreset alloc]init];
        _stores = [NSMutableDictionary new];
        _features = [NSMutableDictionary new];
    }
    return self;
}
- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config{
    if(config.sampleRate<=0&&config.sessionReplayOnErrorSampleRate<=0){
        FTInnerLogWarning(@"[session-replay] skipped: both sampleRate and sessionReplayOnErrorSampleRate are disabled");
        return;
    }
    FTSessionReplayConfig *copyConfig = [config copy];
    [copyConfig mergeWithRemoteConfigModel:[FTRemoteConfigManager sharedInstance].lastRemoteModel];
    FTInnerLogInfo(@"[session-replay] %@",copyConfig.debugDescription);
    [[FTWKWebViewHandler sharedInstance] setEnableLinkRUMKeys:copyConfig.enableLinkRUMKeys];
    FTSessionReplayFeature *sessionReplayFeature = [[FTSessionReplayFeature alloc]initWithConfig:copyConfig];
    FTFeatureStores *srStore = [self registerFeature:sessionReplayFeature];
    [self.stores setValue:srStore forKey:sessionReplayFeature.name];
    [self.features setValue:sessionReplayFeature forKey:sessionReplayFeature.name];
    
    FTResourcesFeature *resourcesFeature = [[FTResourcesFeature alloc]init];
    FTFeatureStores *resourceStore = [self registerFeature:resourcesFeature];
    FTFeatureDataStore *resourceDataStore = [[FTFeatureDataStore alloc]initWithFeature:resourcesFeature.name queue:self.readWriteQueue directory:self.coreDirectory.directory];
    [self.stores setValue:resourceStore forKey:resourcesFeature.name];
    [self.features setValue:resourcesFeature forKey:resourcesFeature.name];
    [sessionReplayFeature startWithRecordStorage:srStore.storage resourceStorage:resourceStore.storage resourceDataStore:resourceDataStore];
    [sessionReplayFeature startRecording];
    FTInnerLogInfo(@"[session-replay] initialized success");
}
- (FTFeatureStores *)registerFeature:(id<FTRemoteFeature>)feature{
    FTFeatureDirectories *directories = [self.coreDirectory featureDirectoriesForFeatureName:feature.name];
    if(directories){
        FTPerformancePreset *performancePreset = [self.performancePreset updateWithOverride:feature.performanceOverride];
        FTFeatureStorage *storage = [[FTFeatureStorage alloc]initWithFeatureName:feature.name
                                                                           queue:self.readWriteQueue
                                                                     directories:directories
                                                                     performance:performancePreset];
        FTFeatureUpload *upload = [FTFeatureUpload createWithFeatureName:feature.name
                                                                   fileReader:storage.reader
                                                                  cacheWriter:storage.cacheWriter
                                                               requestBuilder:feature.requestBuilder
                                                          maxBatchesPerUpload:10
                                                                  performance:performancePreset
                                                                      context:[FTPresetProperty sharedInstance].sessionReplayTags];
        FTFeatureStores *store = [[FTFeatureStores alloc]initWithStorage:storage upload:upload];
        return store;
    }
    return nil;
}

@end

#endif
