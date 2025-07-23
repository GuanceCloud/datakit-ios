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
#import "FTLog+Private.h"
#import "FTTrackerEventDBTool.h"
#import "FTLog+Private.h"
#import "FTJSONUtil.h"
#import "FTConstants.h"
#import "FTRecordModel.h"
#import "FTNetworkConnectivity.h"
#import "FTNetworkInfoManager.h"
static const NSInteger kMaxRetryCount = 5;
static const NSTimeInterval kInitialRetryDelay = 0.5; // Initial 500ms delay

@interface FTDataUploadWorker()
/// Number of data items to upload at once
@property (nonatomic, assign) int uploadPageSize;
@property (nonatomic, assign) int syncSleepTime;
@property (nonatomic, strong) dispatch_queue_t networkQueue;

@property (atomic, assign) BOOL isUploading;
@property (atomic, assign) BOOL finish;

@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) dispatch_source_t timerSource;

@end

@implementation FTDataUploadWorker{
    pthread_rwlock_t _uploadWorkLock;
    pthread_rwlock_t _timerWorkLock;
}
@synthesize uploadWork = _uploadWork;
@synthesize timerSource = _timerSource;
-(instancetype)initWithSyncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime{
    self = [super init];
    if (self) {
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        pthread_rwlock_init(&_timerWorkLock, NULL);
        _uploadPageSize = syncPageSize;
        _syncSleepTime = syncSleepTime;
        _httpClient =[[FTHTTPClient alloc]initWithTimeoutIntervalForRequest:syncPageSize>30?syncPageSize:30];
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _networkQueue = dispatch_queue_create("com.guance.network", attributes);
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
-(void)flushWithSleep:(BOOL)withSleep{
    if (self.isUploading && !self.finish){
        return;
    }
    __weak typeof(self) weakSelf = self;
    if (withSleep) {
        // If Timer already exists, directly reset the trigger time
        dispatch_async(self.networkQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (strongSelf.timerSource) {
                [strongSelf resetExistingTimer];
            } else {
                [strongSelf createNewTimer];
            }
        });
    }else{
        dispatch_sync(self.networkQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if(strongSelf.timerSource) dispatch_source_cancel(strongSelf.timerSource);
            strongSelf.timerSource = nil;
        });
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
        // Execute actual operation after trigger
        [strongSelf _flushSyncData:YES];
        // Cancel and clean up Timer
        dispatch_source_cancel(strongSelf.timerSource);
        strongSelf.timerSource = nil;
    });
    // Set initial trigger time
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC);
    dispatch_source_set_timer(self.timerSource, delay, DISPATCH_TIME_FOREVER, 0);
    // Activate Timer
    dispatch_resume(self.timerSource);
}
-(void)cancelSynchronously{
    self.finish = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.networkQueue, ^{
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
- (void)cancelAsynchronously{
    self.finish = YES;
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
    if (self.isUploading) {
        FTInnerLogDebug(@"[NETWORK]: Network is Uploading. ignore this upload");
        return;
    }
    self.isUploading = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = dispatch_block_create(0, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.errorSampledConsume checkRUMSessionOnErrorDatasExpired];
        if([[FTTrackerEventDBTool sharedManger] getUploadDatasCount]>0){
            if([FTNetworkConnectivity sharedInstance].isConnected){
                [strongSelf privateUpload];
            }else{
                FTInnerLogError(@"[NETWORK] Network unreachable, cancel upload");
            }
        }else{
            strongSelf.isUploading = NO;
            FTInnerLogDebug(@"[NETWORK]: No Data to upload");
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
- (void)privateUpload{
    @try {
        FTInnerLogDebug(@"[NETWORK]:privateUpload start upload");
        [self flushWithType:FT_DATA_TYPE_RUM];
        [self flushWithType:FT_DATA_TYPE_LOGGING];
        self.isUploading = NO;
        FTInnerLogDebug(@"[NETWORK]:privateUpload end upload");
    } @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] Failed to execute upload operation %@",exception);
    } @finally {
        self.isUploading = NO;
    }
}
-(void)flushWithType:(NSString *)type{
    NSArray *events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:self.uploadPageSize withType:type];
    while (events.count > 0) {
        FTInnerLogDebug(@"[NETWORK][%@] Start reporting events (number of events in this report:%lu)", type,(unsigned long)[events count]);
        FTRequest *request = [FTRequest createRequestWithEvents:events type:type];
        if(![self flushWithRequest:request]){
            break;
        }
        FTRecordModel *model = [events lastObject];
        if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:type identify:model._id count:events.count]) {
            FTInnerLogError(@"Failed to delete uploaded data from database");
            break;
        }
        [[request classSerialGenerator] increaseRequestSerialNumber];
        
        if([type isEqualToString:FT_DATA_TYPE_LOGGING]){
            [self.counter uploadLogCount:events.count];
        }else{
            [self.counter uploadRUMCount:events.count];
        }
        if(events.count < self.uploadPageSize){
            break;
        }else{
            // Reduce synchronization rate to lower CPU usage
            [NSThread sleepForTimeInterval:0.001*self.syncSleepTime];
            events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:self.uploadPageSize withType:type];
        }
    }
}
-(BOOL)flushWithRequest:(FTRequest *)request{
    @try {
        __block BOOL success = NO;
        int retryCount = 0;
        NSTimeInterval delay = kInitialRetryDelay; // Initial delay 500ms
        while (!success) {
            @autoreleasepool {
                dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
                [self.httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
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
                        FTInnerLogError(@"[NETWORK] Server exception, try again later responseData = %@",[FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
                    }
                    dispatch_semaphore_signal(flushSemaphore);
                }];
                dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
                
                if (!success) {
                    if (retryCount < kMaxRetryCount) {
                        FTInnerLogDebug(@"[NETWORK] Request failed, preparing for %dth retry, waiting %.0f milliseconds", retryCount + 1, delay*1000);
                        [NSThread sleepForTimeInterval:delay];
                        delay += kInitialRetryDelay; // Backoff
                        retryCount++;
                    } else {
                        FTInnerLogError(@"[NETWORK] Request failed, maximum retry count reached");
                        break; // Reached maximum retry count
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
@end
