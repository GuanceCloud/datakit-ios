//
//  FTRumSessionReplay.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTRumSessionReplay.h"
#import "FTLog+Private.h"
#import "FTResourcesFeature.h"
#import "FTFeatureUpload.h"
#import "FTFileWriter.h"
#import "FTPerformancePreset.h"
#import "FTFeatureStorage.h"
#import "FTDirectory.h"
#import "FTSessionReplayFeature.h"
#import "FTFeatureDataStore.h"
#import "FTModuleManager.h"
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
@property (nonatomic, strong) FTDirectory *coreDirectory;
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
        _coreDirectory = [[FTDirectory alloc]initWithSubdirectoryPath:@"com.guance"];
        _readWriteQueue = dispatch_queue_create("com.guance.file.readwrite", 0);
        _performancePreset = [[FTPerformancePreset alloc]init];
        _stores = [NSMutableDictionary new];
        _features = [NSMutableDictionary new];
    }
    return self;
}
- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config{
    FTInnerLogInfo(@"[session-replay] %@",config.debugDescription);
    if(config.sampleRate<=0){
        return;
    }
    FTSessionReplayFeature *sessionReplayFeature = [[FTSessionReplayFeature alloc]initWithConfig:config];
    FTFeatureStores *srStore = [self registerFeature:sessionReplayFeature];
    [self.stores setValue:srStore forKey:sessionReplayFeature.name];
    [self.features setValue:sessionReplayFeature forKey:sessionReplayFeature.name];
    
    //    FTResourcesFeature *resourcesFeature = [[FTResourcesFeature alloc]init];
    //    FTFeatureStores *resourceStore = [self registerFeature:resourcesFeature];
    //    FTFeatureDataStore *resourceDataStore = [[FTFeatureDataStore alloc]initWithFeature:resourcesFeature.name queue:self.readWriteQueue directory:self.coreDirectory];
    //    [self.stores setValue:resourceStore forKey:resourcesFeature.name];
    //    [self.features setValue:resourcesFeature forKey:resourcesFeature.name];
    [sessionReplayFeature startWithWriter:srStore.storage.writer resourceWriter:nil resourceDataStore:nil];
    FTInnerLogInfo(@"[session-replay] initialized success");
}
- (FTFeatureStores *)registerFeature:(id<FTRemoteFeature>)feature{
    FTDirectory *directory = [self.coreDirectory createSubdirectoryWithPath:feature.name];
    if(directory){
        FTPerformancePreset *performancePreset = [self.performancePreset updateWithOverride:feature.performanceOverride];
        FTFeatureStorage *storage = [[FTFeatureStorage alloc]initWithFeatureName:feature.name queue:self.readWriteQueue directory:directory performance:performancePreset];
        FTFeatureUpload *upload = [[FTFeatureUpload alloc]initWithFeatureName:feature.name
                                                                   fileReader:storage.reader
                                                               requestBuilder:feature.requestBuilder
                                                          maxBatchesPerUpload:10
                                                                  performance:performancePreset
                                                                      context:[[FTModuleManager sharedInstance] getSRProperty]];
        FTFeatureStores *store = [[FTFeatureStores alloc]initWithStorage:storage upload:upload];
        return store;
    }
    return nil;
}

@end
