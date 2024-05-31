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
@interface FTTrackDataManager ()<FTAppLifeCycleDelegate>
@property (atomic, assign) BOOL isUploading;
@property (nonatomic, strong) dispatch_queue_t networkQueue;
/// 是否开启自动上传逻辑（启动时、网络状态变化、写入间隔10s）
@property (atomic, assign) BOOL autoSync;
/// 一次上传数据数量
@property (atomic, assign) int uploadPageSize;
@property (atomic, assign) int syncSleepTime;
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) FTLogDataCache *logDataCache;
@property (nonatomic, strong) dispatch_semaphore_t uploadDelaySemaphore;
@property (atomic, assign) BOOL semaphoreWaiting;
@property (nonatomic, strong) dispatch_source_t uploadDelayTimer;
@end
@implementation FTTrackDataManager
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
        _uploadDelaySemaphore = dispatch_semaphore_create(0);
        _semaphoreWaiting = NO;
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
                [self uploadTrackData];
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
    [self autoSyncOperation];
}
#pragma mark - Upload -
- (void)createUploadDelayTimer{
    if(!_uploadDelayTimer){
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.networkQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 10 *NSEC_PER_SEC), 10 *NSEC_PER_SEC, 0);
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf uploadTrackData];
            [weakSelf cancelUploadDelayTimer];
        });
        //启动定时器
        dispatch_resume(timer);
        _uploadDelayTimer = timer;
    }
}
-(void)cancelUploadDelayTimer{
    if(_uploadDelayTimer){
        dispatch_source_cancel(_uploadDelayTimer);
        _uploadDelayTimer = nil;
    }
}
-(void)autoSyncOperation{
    if(self.isUploading){
        return;
    }
    if(self.autoSync&&!self.uploadDelayTimer){
        if(self.semaphoreWaiting){
            dispatch_semaphore_signal(self.uploadDelaySemaphore);
        }else{
            self.semaphoreWaiting = YES;
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if(self.uploadDelaySemaphore){
                long result = dispatch_semaphore_wait(self.uploadDelaySemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)1*NSEC_PER_MSEC));
                if(result!=0){
                    self.semaphoreWaiting = NO;
                    [self createUploadDelayTimer];
                }
            }
        });
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
                    FTInnerLogError(@"[NETWORK] %@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Request 初始化失败，请检查数据上报地址是否正确"]);
                    success = NO;
                    dispatch_semaphore_signal(flushSemaphore);
                    return;
                }
                NSInteger statusCode = httpResponse.statusCode;
                success = (statusCode >=200 && statusCode < 500);
                FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
                if (statusCode != 200 && data.length>0) {
                    FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 responseData = %@",[FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
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
- (void)shutDown{
    if(self.uploadDelaySemaphore) dispatch_semaphore_signal(self.uploadDelaySemaphore);
    [self.logDataCache insertCacheToDB];
    [self cancelUploadDelayTimer];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    dispatch_sync(self.networkQueue, ^{});
    [[FTTrackerEventDBTool sharedManger] shutDown];
    onceToken = 0;
}
@end
