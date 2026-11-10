//
//  FTDataUploadWorker.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTDiagnosticsBridge.h"
#import "FTDataUploadWorker.h"
#import "FTHTTPClient.h"
#import <stdatomic.h>
#import "FTInnerLog.h"
#import "FTTrackerEventDBTool.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTRecordModel.h"
#import "FTNetworkConnectivity.h"
#import "FTNetworkInfoManager.h"
#import "FTDataFilterManager.h"
#import "FTSerialTimer.h"
#import "FTEarlyCrash.h"
static atomic_bool g_firstAutomaticReservation;
static atomic_bool g_previousEarlyCrash;
static const NSInteger kMaxRetryCount = 5;
static const NSTimeInterval kInitialRetryDelay = 0.5; // Initial 500ms delay
static const NSTimeInterval kUploadDebounceDelay = 0.1;
static const NSTimeInterval kUploadDebounceLeeway = 0;
static const NSInteger kRUMMaxBatchesPerUploadPass = 3;
static const NSInteger kLogMaxBatchesPerUploadPass = 1;
static void *FTDataUploadWorkerNetworkQueueKey = &FTDataUploadWorkerNetworkQueueKey;

typedef NS_ENUM(NSInteger, FTUploadWorkerState) {
    FTUploadWorkerStateIdle,
    FTUploadWorkerStateDebouncing, // 100ms
    FTUploadWorkerStateDelayedReserved, // 2s or 10s
    FTUploadWorkerStateImmediateReserved, // published, not executing yet
    FTUploadWorkerStateUploading,
    FTUploadWorkerStateInvalidated, // shutdown
};

@interface FTDataUploadWorker()
/// Number of data items to upload at once
@property (nonatomic, assign) int uploadPageSize;
@property (nonatomic, assign) int syncSleepTime;
@property (nonatomic, strong) dispatch_queue_t networkQueue;

/// YES when a delayed/immediate reservation or active upload occupies the slot.
@property (nonatomic, assign, readonly) BOOL isUploading;
/// YES when a delayed auto-upload is still in the 100ms debounce window.
@property (nonatomic, assign, readonly) BOOL hasPendingUpload;

// Owned by networkQueue, including access from timer/work bodies.
@property (nonatomic, copy) dispatch_block_t uploadWork;
@property (nonatomic, strong) FTSerialTimer *uploadTimer;
@property (nonatomic, strong) NSObject *uploadReservation;
@property (nonatomic, assign) BOOL firstAutomaticReservation;
@property (nonatomic, assign) BOOL shortenedFirstWait;
@property (nonatomic, assign) NSTimeInterval automaticReservedAt;

@end

@implementation FTDataUploadWorker{
    FTUploadWorkerState _uploadState;
    // Submission identity only; upload state is still owned by networkQueue.
    NSObject *_pendingImmediateSubmission;
}
-(instancetype)initWithSyncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        _uploadState = FTUploadWorkerStateIdle;
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _httpClient =[[FTHTTPClient alloc]initWithTimeoutIntervalForRequest:syncPageSize>30?syncPageSize:30];
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _networkQueue = dispatch_queue_create("com.ft.network", attributes);
        dispatch_queue_set_specific(_networkQueue, FTDataUploadWorkerNetworkQueueKey, &FTDataUploadWorkerNetworkQueueKey, NULL);
        __weak typeof(self) weakSelf = self;
        _uploadTimer = [[FTSerialTimer alloc] initWithQueue:_networkQueue eventHandler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.uploadTimer cancel];
            if (![strongSelf isInvalidated] && strongSelf.hasPendingUpload) {
                [strongSelf _flushSyncData:YES];
            }
        }];
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
        return _uploadState == FTUploadWorkerStateDelayedReserved ||
            _uploadState == FTUploadWorkerStateImmediateReserved || _uploadState == FTUploadWorkerStateUploading;
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
        // Coalesce new writes without moving the first upload deadline.
        // A trailing debounce can starve auto-upload under continuous traffic.
        return NO;
    }
}
- (void)clearPendingUpload{
    @synchronized (self) {
        if (_uploadState == FTUploadWorkerStateDebouncing || _uploadState == FTUploadWorkerStateDelayedReserved ||
            _uploadState == FTUploadWorkerStateImmediateReserved) {
            _uploadState = FTUploadWorkerStateIdle;
        }
    }
}
- (BOOL)isInvalidated{
    @synchronized (self) {
        return _uploadState == FTUploadWorkerStateInvalidated;
    }
}
// Read-only fast rejection preserves the existing behavior while a pass is
// active. It is only an optimization: queue-side admission remains authoritative,
// and submission must be asynchronous even after a non-busy snapshot.
- (BOOL)hasImmediateOrActiveUpload {
    @synchronized (self) {
        return _uploadState == FTUploadWorkerStateImmediateReserved || _uploadState == FTUploadWorkerStateUploading;
    }
}
- (BOOL)beginImmediateUpload{
    @synchronized (self) {
        if (_uploadState != FTUploadWorkerStateIdle &&
            _uploadState != FTUploadWorkerStateDebouncing &&
            _uploadState != FTUploadWorkerStateDelayedReserved) {
            return NO;
        }
        _uploadState = FTUploadWorkerStateImmediateReserved;
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
- (BOOL)beginReservedUpload:(BOOL)withSleep {
    @synchronized (self) {
        FTUploadWorkerState expected = withSleep ? FTUploadWorkerStateDelayedReserved : FTUploadWorkerStateImmediateReserved;
        if (_uploadState != expected) {
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
        _pendingImmediateSubmission = nil;
    }
}
- (void)scheduleDelayedUpload{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if ([strongSelf prepareDelayedUpload]){
            [strongSelf scheduleDelayedUploadTimer];
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
        if ([self hasImmediateOrActiveUpload]) {
            FTInnerLogDebug(@"[NETWORK]: Network is Uploading. ignore this upload");
            return;
        }
        @synchronized (self) {
            if (_pendingImmediateSubmission) return;
            NSObject *submission = [NSObject new];
            _pendingImmediateSubmission = submission;
            __weak typeof(self) weakSelf = self;
            // Enqueue under the short submission lock, never wait for the queue.
            dispatch_async(self.networkQueue, ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                @synchronized (strongSelf) {
                    // Cancellation may retire this identity before admission.
                    if (strongSelf->_pendingImmediateSubmission != submission) return;
                    strongSelf->_pendingImmediateSubmission = nil;
                    if (![strongSelf beginImmediateUpload]) return;
                }
                [strongSelf cancelDelayedUploadTimer];
                [strongSelf cancelUploadWork];
                [strongSelf _flushSyncData:NO];
            });
        }
    }
}
- (void)scheduleDelayedUploadTimer{
    [self.uploadTimer scheduleAfter:kUploadDebounceDelay leeway:kUploadDebounceLeeway];
}
// networkQueue only. State and timer lifecycles are handled by each caller.
- (void)cancelUploadWork {
    dispatch_block_t work = self.uploadWork;
    if (work) dispatch_block_cancel(work);
    self.uploadWork = nil;
    self.uploadReservation = nil;
}
- (void)cancelDelayedUploadTimer{
    [self.uploadTimer cancel];
}
-(void)cancelSynchronously{
    @synchronized (self) { _pendingImmediateSubmission = nil; }
    __weak typeof(self) weakSelf = self;
    [self performSynchronouslyOnNetworkQueue:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf clearPendingUpload];
        [strongSelf cancelUploadWork];
        [strongSelf cancelDelayedUploadTimer];
    }];
}
- (void)cancelAsynchronously{
    @synchronized (self) {
        _pendingImmediateSubmission = nil;
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.networkQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf clearPendingUpload];
            [strongSelf cancelUploadWork];
            [strongSelf cancelDelayedUploadTimer];
        });
    }
}
- (void)invalidateAndCancelPendingUploads{
    [self markInvalidated];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf cancelUploadWork];
        [strongSelf.uploadTimer invalidate];
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
    NSObject *reservation = [NSObject new];
    self.uploadReservation = reservation;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = dispatch_block_create(0, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.uploadReservation != reservation) {
            return;
        }
        if (![strongSelf beginReservedUpload:withSleep]) {
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
            if (needsNextUploadPass && strongSelf.uploadReservation == reservation &&
                ![strongSelf isInvalidated] && [FTNetworkConnectivity sharedInstance].isConnected) {
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
        self.automaticReservedAt = [self automaticUploadNow];
        self.firstAutomaticReservation = [self reserveFirstAutomaticUpload];
        self.shortenedFirstWait = self.firstAutomaticReservation && [self previousEarlyCrashEligible];
        [self scheduleUploadWork:uploadWork afterDelay:self.shortenedFirstWait ? 2 : 10];
    }else{
        FTInnerLogDebug(@"[NETWORK]: start upload");
        dispatch_async(self.networkQueue,uploadWork);
    }
}
// Internal scheduling seams; production behavior remains on the network queue.
- (NSTimeInterval)automaticUploadNow { return ft_earlyCrashNow() / 1e9; }
- (BOOL)reserveFirstAutomaticUpload { return !atomic_exchange(&g_firstAutomaticReservation, true); }
- (BOOL)previousEarlyCrashEligible { return atomic_load(&g_previousEarlyCrash); }
- (void)rememberPreviousEarlyCrash:(BOOL)previousEarlyCrash {
    if (previousEarlyCrash) atomic_store(&g_previousEarlyCrash, true);
}
- (void)updatePreviousEarlyCrash:(BOOL)previousEarlyCrash {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.networkQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || [strongSelf isInvalidated]) return;
        [strongSelf rememberPreviousEarlyCrash:previousEarlyCrash];
        if (![strongSelf previousEarlyCrashEligible] || !strongSelf.firstAutomaticReservation ||
            strongSelf.shortenedFirstWait || !strongSelf.uploadWork) return;
        @synchronized (strongSelf) {
            if (strongSelf->_uploadState != FTUploadWorkerStateDelayedReserved) return;
        }
        strongSelf.shortenedFirstWait = YES;
        NSTimeInterval remaining = MAX(0, 2 - ([strongSelf automaticUploadNow] - strongSelf.automaticReservedAt));
        // A stale timer cannot execute a newer reservation: work checks identity.
        [strongSelf scheduleUploadWork:strongSelf.uploadWork afterDelay:remaining];
    });
}
- (void)scheduleUploadWork:(dispatch_block_t)work afterDelay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.networkQueue, work);
}
- (void)waitBeforeRetry:(NSTimeInterval)delay { [NSThread sleepForTimeInterval:delay]; }
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
        if([FTDiagnosticsBridge enabled]) {
            int64_t oldest=INT64_MAX;for(FTRecordModel *item in events)oldest=MIN(oldest,item.tm/1000000);
            [FTDiagnosticsBridge batch:type count:events.count bytes:-1
                                 ageMs:MAX(0,(int64_t)(NSDate.date.timeIntervalSince1970*1000)-oldest) source:@"oldest_event_timestamp"];
        }
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
                    if(statusCode>=300 && statusCode<500 && statusCode!=403 && statusCode!=429)
                        [FTDiagnosticsBridge record:@"discard" channel:type count:request.events.count bytes:-1 reason:@"non_retryable_response"];
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
                        [self waitBeforeRetry:delay];
                        if ([self isInvalidated]) {
                            return NO;
                        }
                        [FTDiagnosticsBridge record:@"retry" channel:type count:1 bytes:-1 reason:@"retry_scheduled"];
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
    [self.uploadTimer invalidate];
}
@end
