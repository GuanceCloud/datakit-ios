//
//  FTTrackDataManager.m
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTNetworkConnectivity.h"
#import "FTTrackerEventDBTool.h"
#import "FTLog+Private.h"
#import "FTRequest.h"
#import "FTHTTPClient.h"
#import "FTAppLifeCycle.h"
#import "FTConstants.h"
#import <pthread.h>
#import "FTBaseInfoHandler.h"
#import "FTDBDataCachePolicy.h"
#import "FTJSONUtil.h"
#import "FTRUMDataWriteProtocol.h"
#import "FTDataUploadWorker.h"
#import "FTDataWriterWorker.h"
#import "FTNetworkInfoManager.h"
@interface FTTrackDataManager ()<FTAppLifeCycleDelegate,FTNetworkChangeObserver>
/// Whether to enable automatic upload logic (on startup, network status changes, write interval 10s)
@property (atomic, assign) BOOL autoSync;
@property (nonatomic, strong) FTDBDataCachePolicy *dataCachePolicy;
@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) dispatch_source_t timerSource;
@property (nonatomic, strong) NSMutableArray *errorTimeIntervals;
@property (nonatomic, assign) NSTimeInterval cacheInvalidTimeInterval;
@property (nonatomic, strong) FTDataUploadWorker *dataUploadWorker;
@end
@implementation FTTrackDataManager
@synthesize uploadWork = _uploadWork;
@synthesize timerSource = _timerSource;

static  FTTrackDataManager *sharedInstance;
static dispatch_once_t onceToken;

+(instancetype)sharedInstance{
    if(!sharedInstance){
        FTInnerLogError(@"FTTrackDataManager not initialize or SDK already shutDown");
    }
    return sharedInstance;
}
+(instancetype)startWithAutoSync:(BOOL)autoSync syncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime
{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTTrackDataManager alloc]initWithAutoSync:autoSync syncPageSize:syncPageSize syncSleepTime:syncSleepTime];
    });
    return sharedInstance;
}
-(instancetype)initWithAutoSync:(BOOL)autoSync
                   syncPageSize:(int)syncPageSize
                  syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        _dataCachePolicy = [[FTDBDataCachePolicy alloc]init];
        __weak typeof(self) weakSelf = self;
        _dataCachePolicy.callback = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (strongSelf.autoSync){
                [strongSelf.dataUploadWorker flushWithSleep:YES];
            };
        };
        _dataUploadWorker = [[FTDataUploadWorker alloc]initWithSyncPageSize:syncPageSize syncSleepTime:syncSleepTime];
        _dataWriterWorker = [[FTDataWriterWorker alloc]init];
        _dataUploadWorker.errorSampledConsume = _dataWriterWorker;
        _dataUploadWorker.counter = _dataCachePolicy;
        _errorTimeIntervals = [[NSMutableArray alloc]init];
        _cacheInvalidTimeInterval = 60;
        [[FTNetworkConnectivity sharedInstance] start];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
        [self enableAutoSync:autoSync];
    }
    return self;
}
-(FTHTTPClient *)httpClient{
    return _dataUploadWorker.httpClient;
}
- (void)enableAutoSync:(BOOL)autoSync{
    self.autoSync = autoSync;
    if (autoSync) {
        [[FTNetworkConnectivity sharedInstance] addNetworkObserver:self];
    }else{
        [self.dataUploadWorker cancelAsynchronously];
        [[FTNetworkConnectivity sharedInstance] removeNetworkObserver:self];
    }
}
- (void)updateAutoSync:(BOOL)autoSync
          syncPageSize:(int)syncPageSize
         syncSleepTime:(int)syncSleepTime{
    [self enableAutoSync:autoSync];
    [self.dataUploadWorker updateSyncPageSize:syncPageSize syncSleepTime:syncSleepTime];
}
-(void)setEnableLimitWithDb:(BOOL)enable size:(long)size discardNew:(BOOL)discardNew{
    [[FTTrackerEventDBTool sharedManger] setEnableLimitWithDbSize:enable];
    if (enable) {
        [self.dataCachePolicy setDBLimitWithSize:size discardNew:discardNew];
    }
}
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew{
    [self.dataCachePolicy setLogCacheLimitCount:count discardNew:discardNew];
}
- (void)setRUMCacheLimitCount:(int)count discardNew:(BOOL)discardNew{
    [self.dataCachePolicy setRumCacheLimitCount:count discardNew:discardNew];
}
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type{
    if (data == nil) {
        return;
    }
    //Data writing doesn't need additional thread processing, data collection combinations except crash data are all performed in sub-threads
    BOOL insertItemResult = NO;
    switch (type) {
        case FTAddDataRUMCache:
            insertItemResult = [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
        case FTAddDataLogging:
            [self.dataCachePolicy addLogData:data];
            break;
        case FTAddDataRUM:
            insertItemResult = [self.dataCachePolicy addRumData:data];
            break;
    }
    if(self.autoSync&&[self.dataCachePolicy reachHalfLimit]){
        FTInnerLogDebug(@"[NETWORK] reachHalfLimit start uploading");
        [self flushSyncData];
        return;
    }
    if(self.autoSync && insertItemResult){
        [self.dataUploadWorker flushWithSleep:YES];
    }
}
#pragma mark - Network Change Observer -
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription{
    if (connected){
        [self.dataUploadWorker flushWithSleep:YES];
    }
}
#pragma mark - App Life Cycle-
-(void)applicationDidBecomeActive{
    @try {
        if(self.autoSync){
            [self.dataUploadWorker flushWithSleep:YES];
        }
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
-(void)applicationWillResignActive{
    @try {
        [self.dataCachePolicy insertCacheToDB];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"applicationWillResignActive exception %@",exception);
    }
}
-(void)applicationWillTerminate{
    @try {
        [self.dataCachePolicy insertCacheToDB];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
#pragma mark - Upload -
- (void)flushSyncData{
    [self.dataUploadWorker flushWithSleep:NO];
}
- (void)insertCacheToDB{
    [self.dataCachePolicy insertCacheToDB];
}
- (void)shutDown{
    onceToken = 0;
    sharedInstance = nil;
    [self.dataUploadWorker cancelAsynchronously];
    [self.dataCachePolicy insertCacheToDB];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [[FTTrackerEventDBTool sharedManger] shutDown];
}
-(void)dealloc{
    [self.dataUploadWorker cancelAsynchronously];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end
