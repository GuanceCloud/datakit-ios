//
//  FTFeatureUpload.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTFeatureUpload.h"
#import "FTLog+Private.h"
#import "FTNetworkManager.h"
#import "FTResourceRequest.h"
#import "FTJSONUtil.h"
#import "FTReader.h"
#import "FTFeatureRequestBuilder.h"
#import "FTPerformancePreset.h"
#import "FTDataUploadDelay.h"
#import <pthread.h>
@interface FTFeatureUpload(){
    pthread_rwlock_t _readWorkLock;
    pthread_rwlock_t _uploadWorkLock;
}
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_block_t readWork;
@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) id<FTReader> fileReader;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) FTDataUploadDelay *delay;
@end
@implementation FTFeatureUpload
@synthesize readWork = _readWork;
@synthesize uploadWork = _uploadWork;

-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance{
    self = [super init];
    if(self){
        NSString *serialLabel = [NSString stringWithFormat:@"com.guance.%@-upload", featureName];
        _queue = dispatch_queue_create([serialLabel UTF8String], 0);
        pthread_rwlock_init(&_readWorkLock, NULL);
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        _fileReader = fileReader;
        _requestBuilder = requestBuilder;
        _performance = performance;
        _delay = [[FTDataUploadDelay alloc]initWithPerformance:performance];
        _maxBatchesPerUpload = maxBatchesPerUpload;
        _networkManager = [[FTNetworkManager alloc]initWithTimeoutIntervalForRequest:30];
        __weak typeof(self) weakSelf = self;
        dispatch_block_t readWorkItem = ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            //TODO:上传条件判断：电池、省点模式、网络
            
            //读取上传文件
            NSArray<id <FTReadableFile>> *files = [strongSelf.fileReader readFiles:strongSelf.maxBatchesPerUpload];
            if(files == nil || files.count == 0){
                [strongSelf.delay increase];
                [strongSelf scheduleNextCycle];
            }else{
                [self uploadFile:files parameters:@{}];
            }
        };
        self.readWork = readWorkItem;
        dispatch_async(_queue, readWorkItem);
    }
    return self;
}
#pragma mark ========== block_item readwrite lock ==========
-(void)setReadWork:(dispatch_block_t)readWork{
    pthread_rwlock_wrlock(&_readWorkLock);
    _readWork = readWork;
    pthread_rwlock_unlock(&_readWorkLock);
}
-(dispatch_block_t)readWork{
    dispatch_block_t block_t;
    pthread_rwlock_rdlock(&_readWorkLock);
    block_t = _readWork;
    pthread_rwlock_unlock(&_readWorkLock);
    return block_t;
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
- (void)uploadFile:(NSArray<id<FTReadableFile>>*)files parameters:(NSDictionary *)parameters{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if(files.count == 0){
            [strongSelf scheduleNextCycle];
            return;
        }
        NSMutableArray<id<FTReadableFile>>*mutableFiles = [[NSMutableArray alloc]initWithArray:files];
        id<FTReadableFile> file = [mutableFiles lastObject];
        [mutableFiles removeLastObject];
        
        FTBatch *batch = [strongSelf.fileReader readBatch:file];
        if(batch){
            if([strongSelf flushWithEvents:batch.events parameters:parameters]){
                if(mutableFiles.count == 0){
                    [self.delay decrease];
                }
                [self.fileReader markBatchAsRead:batch];
            }else{
                [self.delay increase];
                [strongSelf scheduleNextCycle];
            }
        }
        if(mutableFiles.count == 0){
            [strongSelf scheduleNextCycle];
        }else{
            [strongSelf uploadFile:mutableFiles parameters:parameters];
        }
    };
    self.uploadWork = uploadWork;
    dispatch_async(self.queue, uploadWork);
}
- (void)scheduleNextCycle{
    if(self.readWork){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_delay.current * NSEC_PER_SEC)), self.queue, self.readWork);
    }
}
-(BOOL)flushWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters{
    @try {
        FTInnerLogDebug(@"-----开始上传 session replay-----");
        __block BOOL success = NO;
        dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
        [self.requestBuilder requestWithEvent:events parameters:parameters];
        [self.networkManager sendRequest:self.requestBuilder completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"%@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
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
        return success;
    }  @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }

    return NO;
}
- (void)cancelSynchronously{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.queue, ^{
        if(weakSelf.uploadWork){
            dispatch_block_cancel(weakSelf.uploadWork);
            weakSelf.uploadWork = nil;
        }
        if(weakSelf.readWork){
            dispatch_block_cancel(weakSelf.readWork);
            weakSelf.readWork = nil;
        }
    });
}
@end
