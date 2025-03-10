//
//  FTTrackDataManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#import <QuartzCore/CoreAnimation.h>
#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTNetworkConnectivity.h"
#import "FTTrackerEventDBTool.h"
#import "FTLog+Private.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTAppLifeCycle.h"
#import "FTConstants.h"
#import <pthread.h>
#import "FTBaseInfoHandler.h"
#import "FTDBDataCachePolicy.h"
#import "FTJSONUtil.h"

static const NSInteger kMaxRetryCount = 5;
static const NSTimeInterval kInitialRetryDelay = 0.5; // 初始500ms延迟

@interface FTTrackDataManager ()<FTAppLifeCycleDelegate,FTNetworkChangeObserver>{
    pthread_rwlock_t _uploadWorkLock;
}
@property (atomic, assign) BOOL isUploading;
@property (nonatomic, strong) dispatch_queue_t networkQueue;
/// 是否开启自动上传逻辑（启动时、网络状态变化、写入间隔10s）
@property (atomic, assign) BOOL autoSync;
/// 一次上传数据数量
@property (atomic, assign) int uploadPageSize;
@property (atomic, assign) int syncSleepTime;
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) FTDBDataCachePolicy *dataCachePolicy;
@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (atomic, assign) NSTimeInterval lastDataDate;
@end
@implementation FTTrackDataManager
@synthesize uploadWork = _uploadWork;

static  FTTrackDataManager *sharedInstance;
static dispatch_once_t onceToken;

+(instancetype)sharedInstance{
    if(!sharedInstance){
        sharedInstance = [self startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    }
    return sharedInstance;
}
+(instancetype)startWithAutoSync:(BOOL)autoSync syncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
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
        NSString *serialLabel = @"com.guance.network";
        _networkQueue = dispatch_queue_create_with_target([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        _autoSync = autoSync;
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _networkManager = [[FTNetworkManager alloc]initWithTimeoutIntervalForRequest:syncPageSize>30?syncPageSize:30];
        _dataCachePolicy = [[FTDBDataCachePolicy alloc]init];
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        [self listenNetworkChangeAndAppLifeCycle];
        if(autoSync){
            [self createUploadDelayTimer];
        }
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
        [self uploadTrackData];
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
-(void)applicationDidBecomeActive{
    @try {
        if(self.autoSync){
            [self uploadTrackData];
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
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type{
    //数据写入不用做额外的线程处理，数据采集组合除了崩溃数据，都是在子线程进行的
    switch (type) {
        case FTAddDataLogging:
            [self.dataCachePolicy addLogData:data];
            
            break;
        case FTAddDataRUM:
            [self.dataCachePolicy addRumData:data];
            break;
    }
    if(self.autoSync&&[self.dataCachePolicy reachHalfLimit]){
        //如果正在上传中忽略
        if(!self.isUploading){
            FTInnerLogDebug(@"[NETWORK] reachHalfLimit start uploading");
            [self uploadTrackData];
        }
        return;
    }
    _lastDataDate = CACurrentMediaTime();
}
- (void)createUploadDelayTimer{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = dispatch_block_create(0, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSTimeInterval current = CACurrentMediaTime();
        if(current-strongSelf.lastDataDate>0.1 && [[FTTrackerEventDBTool sharedManger] getDatasCount]>0){
            FTInnerLogDebug(@"[NETWORK]: start upload waiting");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), strongSelf.networkQueue, ^{
                if([FTNetworkConnectivity sharedInstance].isConnected){
                    FTInnerLogDebug(@"[NETWORK]: timer -> privateUpload");
                    [weakSelf privateUpload];
                }else{
                    FTInnerLogError(@"[NETWORK] Network unreachable, cancel upload");
                }
                [weakSelf scheduleNextCycle];
            });
        }else{
            [strongSelf scheduleNextCycle];
        }
    });
    self.uploadWork = uploadWork;
    dispatch_async(_networkQueue, uploadWork);
}
- (void)scheduleNextCycle{
    if(self.uploadWork){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), self.networkQueue, self.uploadWork);
    }
}
-(void)setUploadWork:(dispatch_block_t)uploadWork{
    pthread_rwlock_wrlock(&_uploadWorkLock);
    _uploadWork = uploadWork;
    pthread_rwlock_unlock(&_uploadWorkLock);
}
-(dispatch_block_t)uploadWork{
    dispatch_block_t block_t;
    pthread_rwlock_rdlock(&_uploadWorkLock);
    block_t = _uploadWork;
    pthread_rwlock_unlock(&_uploadWorkLock);
    return block_t;
}
-(void)cancelUploadWork{
    pthread_rwlock_wrlock(&_uploadWorkLock);
    if(_uploadWork){
        dispatch_block_cancel(_uploadWork);
    }
    pthread_rwlock_unlock(&_uploadWorkLock);
}
#pragma mark - Upload -

- (void)uploadTrackData{
    //无网 返回
    if(![FTNetworkConnectivity sharedInstance].isConnected){
        FTInnerLogError(@"[NETWORK] Network unreachable, cancel upload");
        return;
    }
    dispatch_async(self.networkQueue, ^{
        FTInnerLogDebug(@"[NETWORK]: uploadTrackData -> privateUpload");
        [self privateUpload];
    });
}
- (void)privateUpload{
    @try {
        if (self.isUploading) {
            FTInnerLogDebug(@"[NETWORK]: privateUpload ignore");
            return;
        }
        FTInnerLogDebug(@"[NETWORK]:privateUpload start upload");
        self.isUploading = YES;
        [self flushWithType:FT_DATA_TYPE_RUM];
        [self flushWithType:FT_DATA_TYPE_LOGGING];
        self.isUploading = NO;
        FTInnerLogDebug(@"[NETWORK]:privateUpload end upload");
    } @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] 执行上传操作失败 %@",exception);
    } @finally {
        self.isUploading = NO;
    }
}
-(void)flushWithType:(NSString *)type{
    NSArray *events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:self.uploadPageSize withType:type];
    while (events.count > 0) {
        FTInnerLogDebug(@"[NETWORK][%@] 开始上报事件(本次上报事件数:%lu)", type,(unsigned long)[events count]);
        FTRequest *request = [FTRequest createRequestWithEvents:events type:type];
        if(![self flushWithRequest:request]){
            break;
        }
        FTRecordModel *model = [events lastObject];
        if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:type identify:model._id count:events.count]) {
            FTInnerLogError(@"数据库删除已上传数据失败");
            break;
        }
        if([type isEqualToString:FT_DATA_TYPE_LOGGING]){
            _dataCachePolicy.logCount -= events.count;
            [FTBaseInfoHandler increaseLogRequestSerialNumber];
        }else{
            _dataCachePolicy.rumCount -= events.count;
            [FTBaseInfoHandler increaseRumRequestSerialNumber];
        }
        if(events.count < self.uploadPageSize){
            break;
        }else{
            // 减缓同步速率降低CPU使用率
            [NSThread sleepForTimeInterval:0.001*self.syncSleepTime];
            events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:self.uploadPageSize withType:type];
        }
    }
}
-(BOOL)flushWithRequest:(FTRequest *)request{
    @try {
        __block BOOL success = NO;
        int retryCount = 0;
        NSTimeInterval delay = kInitialRetryDelay; // 初始延迟500毫秒
        while (!success) {
            @autoreleasepool {
                dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
                [self.networkManager sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
                    if (error) {
                        FTInnerLogError(@"[NETWORK] Network error: %@",error);
                        success = NO;
                        dispatch_semaphore_signal(flushSemaphore);
                        return;
                    }
                    NSInteger statusCode = httpResponse.statusCode;
                    success = (statusCode >=200 && statusCode < 500);
                    FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
                    if (!success && data.length>0) {
                        FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 responseData = %@",[FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
                    }
                    dispatch_semaphore_signal(flushSemaphore);
                }];
                dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
                
                if (!success) {
                    if (retryCount < kMaxRetryCount) {
                        FTInnerLogDebug(@"[NETWORK] 请求失败，准备进行第%d次重试，等待%.0f毫秒", retryCount + 1, delay*1000);
                        [NSThread sleepForTimeInterval:delay];
                        delay += kInitialRetryDelay; // 退避
                        retryCount++;
                    } else {
                        FTInnerLogError(@"[NETWORK] 请求失败，已达最大重试次数");
                        break; // 达到最大重试次数
                    }
                }
            }
        }
        return success;
    }  @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] exception %@",exception);
    }

    return NO;
}
- (void)insertCacheToDB{
    [self.dataCachePolicy insertCacheToDB];
}
- (void)shutDown{
    [self cancelUploadWork];
    [self.dataCachePolicy insertCacheToDB];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [[FTTrackerEventDBTool sharedManger] shutDown];
    onceToken = 0;
    sharedInstance = nil;
}
@end
