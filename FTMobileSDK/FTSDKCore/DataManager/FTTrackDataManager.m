//
//  FTTrackDataManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTReachability.h"
#import "FTTrackerEventDBTool.h"
#import "FTLog+Private.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTAppLifeCycle.h"
#import "FTConstants.h"
#import <pthread.h>
#import "FTBaseInfoHandler.h"
#import "FTLogDataCache.h"
#import "FTJSONUtil.h"
@interface FTTrackDataManager ()<FTAppLifeCycleDelegate>{
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
@property (nonatomic, strong) FTLogDataCache *logDataCache;
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
-(instancetype)initWithAutoSync:(BOOL)autoSync syncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        NSString *serialLabel = @"com.guance.network";
        _networkQueue = dispatch_queue_create_with_target([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        _autoSync = autoSync;
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _networkManager = [[FTNetworkManager alloc]initWithTimeoutIntervalForRequest:syncPageSize>30?syncPageSize:30];
        _logDataCache = [[FTLogDataCache alloc]init];
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
    [[FTReachability sharedInstance] startNotifier];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(_autoSync){
        __weak typeof(self) weakSelf = self;
        [FTReachability sharedInstance].networkChanged = ^(){
            if([FTReachability sharedInstance].isReachable){
                [weakSelf uploadTrackData];
            }
        };
    }
}
- (void)setLogCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew{
    self.logDataCache.logCacheLimitCount = count;
    self.logDataCache.discardNew = discardNew;
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
        [self.logDataCache insertCacheToDB];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"applicationWillResignActive exception %@",exception);
    }
}
-(void)applicationWillTerminate{
    @try {
        [self.logDataCache insertCacheToDB];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type{
    //数据写入不用做额外的线程处理，数据采集组合除了崩溃数据，都是在子线程进行的
    switch (type) {
        case FTAddDataLogging:
            [self.logDataCache addLogData:data];
            if(self.autoSync&&[self.logDataCache reachHalfLimit]){
                //如果正在上传中忽略
                if(!self.isUploading){
                    [self uploadTrackData];
                }
                return;
            }
            break;
        case FTAddDataNormal:
            [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
        case FTAddDataImmediate:
            [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
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
                FTInnerLogDebug(@"[NETWORK]: timer -> privateUpload");
                [weakSelf privateUpload];
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
#pragma mark - Upload -

- (void)uploadTrackData{
    //无网 返回
    if(![FTReachability sharedInstance].isReachable){
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
            FTInnerLogDebug(@"[NETWORK]: privateUpload ingnore");
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
        if(![self flushWithEvents:events type:type]){
            break;
        }
        FTRecordModel *model = [events lastObject];
        if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:type identify:model._id]) {
            FTInnerLogError(@"数据库删除已上传数据失败");
        }
        if([type isEqualToString:FT_DATA_TYPE_LOGGING]){
            _logDataCache.logCount -= events.count;
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
-(BOOL)flushWithEvents:(NSArray *)events type:(NSString *)type{
    @try {
        __block BOOL success = NO;
        @autoreleasepool {
            FTInnerLogDebug(@"[NETWORK][%@] 开始上报事件(本次上报事件数:%lu)", type,(unsigned long)[events count]);
            dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
            FTRequest *request = [FTRequest createRequestWithEvents:events type:type];
            
            [self.networkManager sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
                if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                    FTInnerLogError(@"[NETWORK][%@] %@", type,[NSString stringWithFormat:@"Network failure: %@", error ? error : @"Request 初始化失败，请检查数据上报地址是否正确"]);
                    success = NO;
                    dispatch_semaphore_signal(flushSemaphore);
                    return;
                }
                NSInteger statusCode = httpResponse.statusCode;
                success = (statusCode >=200 && statusCode < 500);
                FTInnerLogDebug(@"[NETWORK][%@] Upload Response statusCode : %ld",type,(long)statusCode);
                if (statusCode != 200 && data.length>0) {
                    FTInnerLogError(@"[NETWORK][%@] 服务器异常 稍后再试 responseData = %@",type,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                }
                dispatch_semaphore_signal(flushSemaphore);
            }];
            dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
        }
        return success;
    }  @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] exception %@",exception);
    }

    return NO;
}
- (void)insertCacheToDB{
    [self.logDataCache insertCacheToDB];
}
- (void)cancelSynchronously{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.networkQueue, ^{
        if(weakSelf.uploadWork){
            dispatch_block_cancel(weakSelf.uploadWork);
            weakSelf.uploadWork = nil;
        }
    });
}
- (void)shutDown{
    [self cancelSynchronously];
    [self.logDataCache insertCacheToDB];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    dispatch_sync(self.networkQueue, ^{});
    [[FTTrackerEventDBTool sharedManger] shutDown];
    onceToken = 0;
}
@end
