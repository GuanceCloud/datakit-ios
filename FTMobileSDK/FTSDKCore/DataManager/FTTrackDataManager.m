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

@interface FTTrackDataManager ()<FTAppLifeCycleDelegate>
@property (atomic, assign) BOOL isUploading;
@property (atomic, assign) BOOL isWaitingToUpload;
@property (atomic, assign) NSInteger logCount;
@property (nonatomic, strong) NSDate *lastAddLogDate;

@property (nonatomic, strong) dispatch_queue_t networkQueue;
/// 是否开启自动上传逻辑（启动时、网络状态变化、写入间隔10s）
@property (atomic, assign) BOOL autoSync;
/// 一次上传数据数量
@property (atomic, assign) int uploadPageSize;
@property (atomic, assign) int syncSleepTime;
@property (atomic, assign) int logCacheLimitCount;
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) NSMutableArray<FTRecordModel *> *messageCaches;
@property (nonatomic, strong) dispatch_block_t uploadDelayedBlock;
@property (nonatomic, strong) dispatch_source_t logDelayedTimer;
/// logging 类型数据超过最大值后是否废弃最新数据
@property (atomic, assign) BOOL discardNew;
@end
@implementation FTTrackDataManager{
    pthread_mutex_t _lock;
}
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
        sharedInstance = [[super allocWithZone:nil] initWithAutoSync:autoSync syncPageSize:syncPageSize syncSleepTime:syncSleepTime];
    });
    return sharedInstance;
}
-(instancetype)initWithAutoSync:(BOOL)autoSync syncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        NSString *serialLabel = @"com.guance.network";
        _networkQueue = dispatch_queue_create_with_target([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        pthread_mutex_init(&(self->_lock), NULL);
        _autoSync = autoSync;
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _logCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
        NSURLSessionConfiguration *sessionConfiguration = nil;
        if (syncPageSize>30) {
            sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            sessionConfiguration.timeoutIntervalForRequest = syncPageSize;
        }
        _networkManager = [[FTNetworkManager alloc]initWithSessionConfiguration:sessionConfiguration];
        _logCacheLimitCount = FT_DB_CONTENT_MAX_COUNT;
        __weak __typeof(self) weakSelf = self;
        _uploadDelayedBlock = dispatch_block_create(0, ^{
            weakSelf.isWaitingToUpload = NO;
            [weakSelf uploadTrackData];
        });
        [self listenNetworkChangeAndAppLifeCycle];
    }
    return self;
}
//监听网络状态 网络连接成功 触发一次上传操作
- (void)listenNetworkChangeAndAppLifeCycle{
    [[FTReachability sharedInstance] startNotifier];
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    if(_autoSync){
        [FTReachability sharedInstance].networkChanged = ^(){
            if([FTReachability sharedInstance].isReachable){
                [self uploadTrackData];
            }
        };
    }
}
- (FTTrackDataManager *(^)(int))setLogCacheLimitCount{
    return ^(int value) {
        self.logCacheLimitCount = value;
        return self;
    };
}
- (FTTrackDataManager *(^)(BOOL))setLogDiscardNew{
    return ^(BOOL value) {
        self.discardNew = value;
        return self;
    };
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
        [self insertCacheToDB];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"applicationWillResignActive exception %@",exception);
    }
}
-(void)applicationWillTerminate{
    @try {
        [self insertCacheToDB];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type{
    //数据写入不用做额外的线程处理，数据采集组合除了崩溃数据，都是在子线程进行的
    switch (type) {
        case FTAddDataLogging:
            [self insertLoggingItems:data];
            return;
        case FTAddDataNormal:
            [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
        case FTAddDataImmediate:
            [self insertCacheToDB];
            [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
    }
    [self autoSyncOperation];
}
#pragma mark - Log -
-(void)insertLoggingItems:(FTRecordModel *)item{
    if (!item) {
        return;
    }
    pthread_mutex_lock(&_lock);
    [self.messageCaches addObject:item];
    _logCount += 1;
    NSInteger count = self.logCacheLimitCount - _logCount;
    if (self.messageCaches.count>=20) {
        // 当前日志已经达到最大限额
        if(count < 0){
            if(!self.discardNew){
                [[FTTrackerEventDBTool sharedManger] deleteLoggingItem:-count];
            }else{
                NSInteger sum = count+self.messageCaches.count;
                if (sum>=0) {
                    [self.messageCaches removeObjectsInRange:NSMakeRange(sum, self.messageCaches.count-sum)];
                }
            }
            _logCount += count;
        }
        [[FTTrackerEventDBTool sharedManger] insertItemsWithDatas:self.messageCaches];
        [self.messageCaches removeAllObjects];
        pthread_mutex_unlock(&_lock);
        // 日志写入数据库，触发自动同步逻辑操作
        [self autoSyncOperation];
    }else{
        pthread_mutex_unlock(&_lock);
        //日志写入频繁时
        if(self.lastAddLogDate){
            if([[NSDate date] timeIntervalSinceDate:self.lastAddLogDate]<0.1){
                if(self.logDelayedTimer){
                    dispatch_source_cancel(_logDelayedTimer);
                    _logDelayedTimer = nil;
                }
            }
        }
        self.lastAddLogDate = [NSDate date];
        if(!self.logDelayedTimer){
            [self startLogDelayedTimer];
        }
    }
    // 剩余可以添加的日志数量超多限额一半
    if (count<self.logCacheLimitCount/2) {
        // 剩余可以添加的日志数量不足限额一半，触发日志同步操作
        if(_autoSync){
            [self uploadTrackData];
        }
    }
}
-(void)startLogDelayedTimer{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _logDelayedTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    __weak __typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(weakSelf.logDelayedTimer, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf insertCacheToDB];
        dispatch_source_cancel(strongSelf->_logDelayedTimer);
        strongSelf.logDelayedTimer = nil;
    });
    dispatch_time_t startDelayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC));
    dispatch_source_set_timer(_logDelayedTimer,startDelayTime,10*NSEC_PER_SEC,0);
    dispatch_resume(_logDelayedTimer);
}
-(void)insertCacheToDB{
    pthread_mutex_lock(&_lock);
    if (self.messageCaches.count > 0) {
        NSArray *array = [self.messageCaches copy];
        self.messageCaches = nil;
        pthread_mutex_unlock(&_lock);
        [[FTTrackerEventDBTool sharedManger] insertItemsWithDatas:array];
    }else{
        pthread_mutex_unlock(&_lock);
    }
}
- (NSMutableArray<FTRecordModel *> *)messageCaches {
    if (!_messageCaches) {
        _messageCaches = [NSMutableArray array];
    }
    return _messageCaches;
}
#pragma mark - Upload -
-(void)autoSyncOperation{
    if(self.autoSync){
        if (!self.isWaitingToUpload) {
            self.isWaitingToUpload = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), self.networkQueue, ^{
                self.uploadDelayedBlock();
            });
        }
    }
}
- (void)uploadTrackData{
    //无网 返回
    if(![FTReachability sharedInstance].isReachable){
        FTInnerLogError(@"[NETWORK] Network unreachable, cancel upload");
        return;
    }
    dispatch_async(self.networkQueue, ^{
        [self privateUpload];
    });
}
- (void)privateUpload{
    @try {
        if (self.isUploading) {
            return;
        }
        self.isUploading = YES;
        [self flushWithType:FT_DATA_TYPE_RUM];
        [self flushWithType:FT_DATA_TYPE_LOGGING];
        self.isUploading = NO;
    } @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] 执行上传操作失败 %@",exception);
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
            _logCount -= events.count;
        }
        if(events.count < self.uploadPageSize){
            break;
        }else{
            // 减缓同步速率降低CPU使用率
            if(self.syncSleepTime>0){
                dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.syncSleepTime * NSEC_PER_MSEC)), dispatch_get_global_queue(0, 0), ^{
                    dispatch_semaphore_signal(flushSemaphore);
                });
                dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
            }
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
                    FTInnerLogError(@"[NETWORK] %@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Request 初始化失败，请检查数据上报地址是否正确"]);
                    success = NO;
                    dispatch_semaphore_signal(flushSemaphore);
                    return;
                }
                NSInteger statusCode = httpResponse.statusCode;
                success = (statusCode >=200 && statusCode < 500);
                FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
                if (!success) {
                    FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 response = %@",httpResponse);
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
- (void)shutDown{
    [self insertCacheToDB];
    if(_logDelayedTimer) dispatch_source_cancel(_logDelayedTimer);
    if (self.uploadDelayedBlock) dispatch_block_cancel(self.uploadDelayedBlock);
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    [[FTTrackerEventDBTool sharedManger] shutDown];
    onceToken = 0;
}
@end
