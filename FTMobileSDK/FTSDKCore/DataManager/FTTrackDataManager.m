//
//  FTTrackDataManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
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

@interface FTTrackDataManager ()<FTAppLifeCycleDelegate,FTNetworkChangeObserver>
/// 是否开启自动上传逻辑（启动时、网络状态变化、写入间隔10s）
@property (nonatomic, assign) BOOL autoSync;
@property (nonatomic, strong) FTHTTPClient *httpClient;
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
        _dataUploadWorker = [[FTDataUploadWorker alloc]initWithAutoSync:autoSync syncPageSize:syncPageSize syncSleepTime:syncSleepTime];
        _dataWriterWorker = [[FTDataWriterWorker alloc]init];
        _dataUploadWorker.errorSampledConsume = _dataWriterWorker;
        _dataUploadWorker.counter = _dataCachePolicy;
        _autoSync = autoSync;
        if (autoSync) {
            __weak typeof(self) weakSelf = self;
            _dataCachePolicy.callback = ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf.dataUploadWorker flushWithSleep:YES];
            };
        }
        _errorTimeIntervals = [[NSMutableArray alloc]init];
        _cacheInvalidTimeInterval = 60;
        [self listenNetworkChangeAndAppLifeCycle];
    }
    return self;
}
//监听网络状态 网络连接成功 触发一次上传操作
- (void)listenNetworkChangeAndAppLifeCycle{
    [[FTNetworkConnectivity sharedInstance] start];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(_autoSync){
        [[FTNetworkConnectivity sharedInstance] addNetworkObserver:self];
    }
}
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription{
    if (connected){
        [self.dataUploadWorker flushWithSleep:YES];
    }
}
-(void)setDBLimitWithSize:(long)size discardNew:(BOOL)discardNew{
    [[FTTrackerEventDBTool sharedManger] setEnableLimitWithDbSize:YES];
    [self.dataCachePolicy setDBLimitWithSize:size discardNew:discardNew];
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
    //数据写入不用做额外的线程处理，数据采集组合除了崩溃数据，都是在子线程进行的
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
