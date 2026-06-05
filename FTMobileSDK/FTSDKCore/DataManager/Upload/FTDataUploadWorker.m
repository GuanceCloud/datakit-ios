//
//  FTDataUploadWorker.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTDataUploadWorker.h"
#import "FTHTTPClient.h"
#import <pthread.h>
#import "FTInnerLog.h"
#import "FTTrackerEventDBTool.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTRecordModel.h"
#import "FTNetworkConnectivity.h"
#import "FTNetworkInfoManager.h"
#import "FTDataFilterManager.h"
static const NSInteger kMaxRetryCount = 5;
static const NSTimeInterval kInitialRetryDelay = 0.5; // Initial 500ms delay
static const NSInteger kRUMMaxBatchesPerUploadPass = 3;
static const NSInteger kLogMaxBatchesPerUploadPass = 1;
static void *FTDataUploadWorkerNetworkQueueKey = &FTDataUploadWorkerNetworkQueueKey;

typedef NS_ENUM(NSInteger, FTUploadWorkerState) {
    FTUploadWorkerStateIdle,
    FTUploadWorkerStateDebouncing, // 100ms
    FTUploadWorkerStateDelayedReserved, // 10s
    FTUploadWorkerStateUploading,
    FTUploadWorkerStateInvalidated, // shutdown
};

@interface FTDataUploadWorker()
/// Number of data items to upload at once
@property (nonatomic, assign) int uploadPageSize;
@property (nonatomic, assign) int syncSleepTime;
@property (nonatomic, strong) dispatch_queue_t networkQueue;

/// YES when the upload slot is occupied by a delayed reservation or active upload.
@property (nonatomic, assign, readonly) BOOL isUploading;
/// YES when a delayed auto-upload is still in the 100ms debounce window.
@property (nonatomic, assign, readonly) BOOL hasPendingUpload;

@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) dispatch_source_t timerSource;

@end

@implementation FTDataUploadWorker{
    pthread_rwlock_t _uploadWorkLock;
    FTUploadWorkerState _uploadState;
}
@synthesize uploadWork = _uploadWork;
@synthesize timerSource = _timerSource;
-(instancetype)initWithSyncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        _uploadState = FTUploadWorkerStateIdle;
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _httpClient =[[FTHTTPClient alloc]initWithTimeoutIntervalForRequest:syncPageSize>30?syncPageSize:30];
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _networkQueue = dispatch_queue_create("com.ft.network", attributes);
        dispatch_queue_set_specific(_networkQueue, FTDataUploadWorkerNetworkQueueKey, &FTDataUploadWorkerNetworkQueueKey, NULL);
    }
    return self;
}
-(void)updateSyncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.uploadPageSize = syncPageSize;
        strongSelf.syncSleepTime = syncSleepTime;
    });
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
- (void)performSynchronouslyOnNetworkQueue:(dispatch_block_t)block{
    if (!block) {
        return;
    }
    if (dispatch_get_specific(FTDataUploadWorkerNetworkQueueKey) == &FTDataUploadWorkerNetworkQueueKey) {
        block();
    } else {
        dispatch_sync(self.networkQueue, block);
    }
}
- (BOOL)isUploading{
    @synchronized (self) {
        return _uploadState == FTUploadWorkerStateDelayedReserved || _uploadState == FTUploadWorkerStateUploading;
    }
}
- (BOOL)hasPendingUpload{
    @synchronized (self) {
        return _uploadState == FTUploadWorkerStateDebouncing;
    }
}
- (BOOL)prepareDelayedUpload{
    @synchronized (self) {
        if (_uploadState == FTUploadWorkerStateIdle) {
            _uploadState = FTUploadWorkerStateDebouncing;
            return YES;
        }
        return _uploadState == FTUploadWorkerStateDebouncing;
    }
}
- (void)clearDelayedUploadPending{
    @synchronized (self) {
        if (_uploadState == FTUploadWorkerStateDebouncing || _uploadState == FTUploadWorkerStateDelayedReserved) {
            _uploadState = FTUploadWorkerStateIdle;
        }
    }
}
- (BOOL)isInvalidated{
    @synchronized (self) {
        return _uploadState == FTUploadWorkerStateInvalidated;
    }
}
- (BOOL)beginImmediateUpload{
    @synchronized (self) {
        if (_uploadState != FTUploadWorkerStateIdle &&
            _uploadState != FTUploadWorkerStateDebouncing &&
            _uploadState != FTUploadWorkerStateDelayedReserved) {
            return NO;
        }
        _uploadState = FTUploadWorkerStateUploading;
        return YES;
    }
}
- (BOOL)reserveDelayedUploadIfPending{
    @synchronized (self) {
        if (_uploadState != FTUploadWorkerStateDebouncing) {
            return NO;
        }
        _uploadState = FTUploadWorkerStateDelayedReserved;
        return YES;
    }
}
- (BOOL)beginReservedDelayedUpload{
    @synchronized (self) {
        if (_uploadState != FTUploadWorkerStateDelayedReserved) {
            return NO;
        }
        _uploadState = FTUploadWorkerStateUploading;
        return YES;
    }
}
- (void)markUploadFinished{
    @synchronized (self) {
        if (_uploadState == FTUploadWorkerStateUploading) {
            _uploadState = FTUploadWorkerStateIdle;
        }
    }
}
- (void)markInvalidated{
    @synchronized (self) {
        _uploadState = FTUploadWorkerStateInvalidated;
    }
}
- (void)scheduleDelayedUpload{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if ([strongSelf prepareDelayedUpload]){
            if (strongSelf.timerSource) {
                [strongSelf resetExistingTimer];
            } else {
                [strongSelf createNewTimer];
            }
        }
    });
}
-(void)flushWithSleep:(BOOL)withSleep{
    if ([self isInvalidated]) {
        FTInnerLogDebug(@"[NETWORK]: Upload worker is invalidated. ignore this upload");
        return;
    }
    if (withSleep) {
        [self scheduleDelayedUpload];
    }else{
        if (![self beginImmediateUpload]) {
            FTInnerLogDebug(@"[NETWORK]: Network is Uploading. ignore this upload");
            return;
        }
        __weak typeof(self) weakSelf = self;
        [self performSynchronouslyOnNetworkQueue:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if(strongSelf.timerSource) dispatch_source_cancel(strongSelf.timerSource);
            strongSelf.timerSource = nil;
            if(strongSelf.uploadWork) dispatch_block_cancel(strongSelf.uploadWork);
            strongSelf.uploadWork = nil;
        }];
        [self _flushSyncData:NO];
    }
}
// Reset the trigger time of existing Timer
- (void)resetExistingTimer {
    // Calculate new trigger time (current time + 100ms)
    dispatch_time_t newDelay = dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC);
    // Update Timer trigger time (no need to resume again)
    dispatch_source_set_timer(self.timerSource, newDelay, DISPATCH_TIME_FOREVER, 0);
}
- (void)createNewTimer {
    // Create Timer and associate with global queue (or custom queue)
    self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.networkQueue);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timerSource, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // Cancel and clean up Timer
        dispatch_source_cancel(strongSelf.timerSource);
        strongSelf.timerSource = nil;
        if (![strongSelf isInvalidated] && strongSelf.hasPendingUpload) {
            // Execute actual operation after trigger
            [strongSelf _flushSyncData:YES];
        }
    });
    // Set initial trigger time
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC);
    dispatch_source_set_timer(self.timerSource, delay, DISPATCH_TIME_FOREVER, 0);
    // Activate Timer
    dispatch_resume(self.timerSource);
}
-(void)cancelSynchronously{
    [self clearDelayedUploadPending];
    __weak typeof(self) weakSelf = self;
    [self performSynchronouslyOnNetworkQueue:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if(strongSelf.uploadWork) dispatch_block_cancel(strongSelf.uploadWork);
        strongSelf.uploadWork = nil;
        if(strongSelf.timerSource) dispatch_source_cancel(strongSelf.timerSource);
        strongSelf.timerSource = nil;
    }];
}
- (void)cancelAsynchronously{
    [self clearDelayedUploadPending];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if(strongSelf.uploadWork) dispatch_block_cancel(strongSelf.uploadWork);
        strongSelf.uploadWork = nil;
        if(strongSelf.timerSource) dispatch_source_cancel(strongSelf.timerSource);
        strongSelf.timerSource = nil;
    });
}
- (void)invalidateAndCancelPendingUploads{
    [self markInvalidated];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if(strongSelf.uploadWork) dispatch_block_cancel(strongSelf.uploadWork);
        strongSelf.uploadWork = nil;
        if(strongSelf.timerSource) dispatch_source_cancel(strongSelf.timerSource);
        strongSelf.timerSource = nil;
    });
}
- (void)_flushSyncData:(BOOL)withSleep{
    if ([self isInvalidated]) {
        return;
    }
    if (withSleep && ![self reserveDelayedUploadIfPending]) {
        FTInnerLogDebug(@"[NETWORK]: Network is Uploading. ignore this upload");
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = dispatch_block_create(0, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (withSleep && ![strongSelf beginReservedDelayedUpload]) {
            return;
        }
        BOOL needsNextUploadPass = NO;
        @try {
            if ([strongSelf isInvalidated]) {
                return;
            }
            [[FTDataFilterManager sharedInstance] updateRemoteFilterIfNeededWithForce:NO];
            [strongSelf.errorSampledConsume checkRUMSessionOnErrorDatasExpired];
            if([[FTTrackerEventDBTool sharedManager] getUploadDatasCount]>0){
                if([FTNetworkConnectivity sharedInstance].isConnected){
                    needsNextUploadPass = [strongSelf privateUpload];
                }else{
                    FTInnerLogError(@"[NETWORK] Network unreachable, cancel upload");
                }
            }else{
                FTInnerLogDebug(@"[NETWORK]: No Data to upload");
            }
        } @finally {
            [strongSelf markUploadFinished];
            if (needsNextUploadPass && ![strongSelf isInvalidated] && [FTNetworkConnectivity sharedInstance].isConnected) {
                FTInnerLogDebug(@"[NETWORK]: Upload pass has remaining data, schedule next upload pass");
                if ([strongSelf beginImmediateUpload]) {
                    [strongSelf _flushSyncData:NO];
                }
            }
        }
    });
    self.uploadWork = uploadWork;
    if (withSleep){
        FTInnerLogDebug(@"[NETWORK]: start upload waiting");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), self.networkQueue, uploadWork);
    }else{
        FTInnerLogDebug(@"[NETWORK]: start upload");
        dispatch_async(self.networkQueue,uploadWork);
    }
}
- (BOOL)privateUpload{
    @try {
        if ([self isInvalidated]) {
            return NO;
        }
        FTInnerLogDebug(@"[NETWORK]:privateUpload start upload");
        BOOL rumNeedsNextUploadPass = [self flushWithType:FT_DATA_TYPE_RUM maxBatchesPerUploadPass:kRUMMaxBatchesPerUploadPass];
        BOOL logNeedsNextUploadPass = [self flushWithType:FT_DATA_TYPE_LOGGING maxBatchesPerUploadPass:kLogMaxBatchesPerUploadPass];
        FTInnerLogDebug(@"[NETWORK]:privateUpload end upload");
        return rumNeedsNextUploadPass || logNeedsNextUploadPass;
    } @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] Failed to execute upload operation %@",exception);
    }
    return NO;
}
- (BOOL)flushWithType:(NSString *)type maxBatchesPerUploadPass:(NSInteger)maxBatchesPerUploadPass{
    NSInteger uploadBatchCount = 0;
    while (uploadBatchCount < maxBatchesPerUploadPass &&
           ![self isInvalidated]) {
        NSArray *events = [[FTTrackerEventDBTool sharedManager] getFirstRecords:self.uploadPageSize withType:type];
        if (events.count == 0) {
            return NO;
        }
        FTInnerLogDebug(@"[NETWORK][%@] Start reporting events (number of events in this report:%lu)", type,(unsigned long)[events count]);
        FTRequest *request = [FTRequest createRequestWithEvents:events type:type];
        if (!request) {
            FTInnerLogError(@"[NETWORK][%@] Failed to create request", type);
            return NO;
        }

        if (![self flushWithRequest:request type:type]) {
            return NO;
        }
        FTRecordModel *model = [events lastObject];
        if (![[FTTrackerEventDBTool sharedManager] deleteItemWithType:type identify:model._id count:events.count]) {
            FTInnerLogError(@"Failed to delete uploaded data from database");
            return NO;
        }
        [[request classSerialGenerator] increaseRequestSerialNumber];

        if([type isEqualToString:FT_DATA_TYPE_LOGGING]){
            [self.counter uploadLogCount:events.count];
        }else{
            [self.counter uploadRUMCount:events.count];
        }
        FTInnerLogDebug(@"[NETWORK][%@] Batch upload succeeded (number of events in this report:%lu)", type,(unsigned long)[events count]);
        uploadBatchCount++;
        if (events.count < self.uploadPageSize) {
            return NO;
        }
        if (uploadBatchCount >= maxBatchesPerUploadPass) {
            FTInnerLogDebug(@"[NETWORK][%@] Stop current upload pass because batch limit reached", type);
            return YES;
        }
        NSTimeInterval sleepTime = 0.001*self.syncSleepTime;
        if (sleepTime > 0) {
            [NSThread sleepForTimeInterval:sleepTime];
        }
    }
    return NO;
}
-(BOOL)flushWithRequest:(FTRequest *)request type:(NSString *)type{
    @try {
        __block BOOL success = NO;
        int requestRetryCount = 0;
        NSTimeInterval delay = kInitialRetryDelay; // Initial delay 500ms
        while (!success) {
            if ([self isInvalidated]) {
                return NO;
            }
            @autoreleasepool {
                __block BOOL requestCreationFailed = NO;
                dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
                [self.httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nullable httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
                    if (error) {
                        requestCreationFailed = [error.domain isEqualToString:FTHTTPClientErrorDomain] && error.code == FTHTTPClientErrorCodeRequestCreationFailed;
                        if (requestCreationFailed) {
                            FTInnerLogDebug(@"[NETWORK][%@] Stop upload because request could not be created: %@", type,error);
                        }else{
                            FTInnerLogError(@"[NETWORK] Network error: %@",error);
                        }
                        success = NO;
                        dispatch_semaphore_signal(flushSemaphore);
                        return;
                    }
                    NSInteger statusCode = httpResponse.statusCode;
                    success = (statusCode >=200 && statusCode < 500 && statusCode != 403 && statusCode != 429);
                    FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
                    if (!success && data.length>0) {
                        FTInnerLogError(@"[NETWORK] Server exception, try again later responseData = %@",[FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
                    }
                    dispatch_semaphore_signal(flushSemaphore);
                }];
                dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);

                if (requestCreationFailed) {
                    return NO;
                }
                if (!success) {
                    if ([self isInvalidated]) {
                        return NO;
                    }
                    if (requestRetryCount < kMaxRetryCount) {
                        FTInnerLogDebug(@"[NETWORK] Request failed, preparing for %dth retry, waiting %.0f milliseconds", requestRetryCount + 1, delay*1000);
                        [NSThread sleepForTimeInterval:delay];
                        if ([self isInvalidated]) {
                            return NO;
                        }
                        requestRetryCount++;
                        delay += kInitialRetryDelay; // Backoff
                    } else {
                        FTInnerLogError(@"[NETWORK] Request failed, maximum retry count reached");
                        return NO;
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
-(void)dealloc{
    pthread_rwlock_destroy(&_uploadWorkLock);
}
@end
