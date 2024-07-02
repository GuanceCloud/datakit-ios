//
//  FTSessionReplayUploader.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayUploader.h"
#import "FTLog+Private.h"
#import "FTNetworkManager.h"
#import "FTResourceRequest.h"
#import "FTJSONUtil.h"
#import "FTReader.h"
#import "FTFeatureRequestBuilder.h"
#import "FTPerformancePreset.h"
#import "FTDataUploadDelay.h"

@interface FTSessionReplayUploader()
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) dispatch_queue_t queue;
// TODO:readwrite lock
@property (nonatomic, strong) dispatch_block_t readWork;
@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) id<FTReader> fileReader;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) FTDataUploadDelay *delay;
@end
@implementation FTSessionReplayUploader
-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance{
    self = [super init];
    if(self){
        NSString *serialLabel = [NSString stringWithFormat:@"com.guance.%@-upload", featureName];
        _queue = dispatch_queue_create([serialLabel UTF8String], 0);
        _fileReader = fileReader;
        _requestBuilder = requestBuilder;
        _performance = performance;
        _delay = [[FTDataUploadDelay alloc]initWithPerformance:performance];
        _maxBatchesPerUpload = maxBatchesPerUpload;
        __weak typeof(self) weakSelf = self;
        dispatch_block_t readWorkItem = ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            //上传条件判断：电池、网络
            
            //读取上传文件
            NSArray<id <FTReadableFile>> *files = [strongSelf.fileReader readFiles:strongSelf.maxBatchesPerUpload];
            if(files == nil || files.count == 0){
                [strongSelf.delay increase];
                [strongSelf scheduleNextCycle];
            }else{
                [self uploadFile:files parameters:@{}];
            }
        };
        _readWork = readWorkItem;
        dispatch_async(_queue, _readWork);
    }
    return self;
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
            [strongSelf flushWithEvents:batch.events parameters:parameters];
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
        dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
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
        if(weakSelf.uploadWork) weakSelf.uploadWork = nil;
        if(weakSelf.readWork) weakSelf.readWork = nil;
    });
}
@end
