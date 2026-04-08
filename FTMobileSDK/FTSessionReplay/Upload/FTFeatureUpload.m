//
//  FTFeatureUpload.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTFeatureUpload.h"
#import "FTSessionReplayCoreImports.h"
#import "FTResourceRequest.h"
#import "FTReader.h"
#import "FTFeatureRequestBuilder.h"
#import "FTPerformancePreset.h"
#import "FTDataUploadDelay.h"
#import <pthread.h>
#import "FTTLV.h"
#import "FTFile.h"
#import "FTUploadConditions.h"
#import "FTSegmentJSON.h"
#import "FTDataStore.h"
#import "FTFileWriter.h"
#import "FTResourceCheckRequest.h"
#import "FTSRRecord.h"

@interface FTFeatureUpload()<NSCacheDelegate>{
    pthread_rwlock_t _readWorkLock;
    pthread_rwlock_t _uploadWorkLock;
}
@property (nonatomic, strong) FTHTTPClient *httpClient;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_block_t readWork;
@property (nonatomic, strong) dispatch_block_t uploadWork;
@property (nonatomic, strong) id<FTReader> fileReader;
@property (nonatomic, strong) id<FTCacheWriter> cacheWriter;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) FTDataUploadDelay *delay;
@property (nonatomic, strong) FTUploadConditions *uploadConditions;
@property (nonatomic, strong) NSDictionary *context;
@property (nonatomic, copy) NSString *featureName;
@end
@implementation FTFeatureUpload
@synthesize readWork = _readWork;
@synthesize uploadWork = _uploadWork;
+(FTFeatureUpload *)createWithFeatureName:(NSString *)featureName
                               fileReader:(id<FTReader>)fileReader
                              cacheWriter:(id<FTCacheWriter>)cacheWriter
                           requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
                      maxBatchesPerUpload:(int)maxBatchesPerUpload
                              performance:(FTPerformancePreset *)performance
                                  context:(nonnull NSDictionary *)context{
    if ([featureName isEqualToString:@"session-replay-resources"]) {
        return [[FTImageFeatureUpload alloc]initWithFeatureName:featureName fileReader:fileReader cacheWriter:cacheWriter requestBuilder:requestBuilder maxBatchesPerUpload:maxBatchesPerUpload performance:performance context:context];
    }else{
        return [[FTFeatureUpload alloc]initWithFeatureName:featureName fileReader:fileReader cacheWriter:cacheWriter requestBuilder:requestBuilder maxBatchesPerUpload:maxBatchesPerUpload performance:performance context:context];
    }
}
-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                       cacheWriter:(id<FTCacheWriter>)cacheWriter
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance
                           context:(nonnull NSDictionary *)context
{
    self = [super init];
    if(self){
        NSString *serialLabel = [NSString stringWithFormat:@"com.ft.%@-upload", featureName];
        _queue = dispatch_queue_create([serialLabel UTF8String], 0);
        _featureName = featureName;
        pthread_rwlock_init(&_readWorkLock, NULL);
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        _fileReader = fileReader;
        _cacheWriter = cacheWriter;
        _requestBuilder = requestBuilder;
        _performance = performance;
        _context = context;
        _delay = [[FTDataUploadDelay alloc]initWithPerformance:performance];
        _maxBatchesPerUpload = maxBatchesPerUpload;
        _httpClient = [[FTHTTPClient alloc]initWithTimeoutIntervalForRequest:30];
        _uploadConditions = [[FTUploadConditions alloc]init];
        [_uploadConditions startObserver];
        [self startReadWork];
    }
    return self;
}
- (void)startReadWork{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t readWorkItem = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.cacheWriter cleanup];
        NSArray *conditions = [strongSelf.uploadConditions checkForUpload];
        BOOL canUpload = conditions.count == 0;
        //Read upload files
        NSArray<id <FTReadableFile>> *files = canUpload?[strongSelf.fileReader readFiles:strongSelf.maxBatchesPerUpload]:nil;
        if(files == nil || files.count == 0){
            FTInnerLogDebug(@"[NETWORK][%@] No upload:%@",strongSelf.featureName,canUpload?@"No files to upload":[NSString stringWithFormat:@"[upload was skipped because:%@]",[conditions componentsJoinedByString:@" AND "]]);
            [strongSelf.delay increase];
            [strongSelf scheduleNextCycle];
        }else{
            FTInnerLogDebug(@"[NETWORK][%@] Uploading batches... ",strongSelf.featureName);
            [strongSelf uploadFile:files parameters:strongSelf.context];
        }
    };
    self.readWork = readWorkItem;
    dispatch_async(_queue, readWorkItem);
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
#pragma mark ========== deal upload data ==========
- (void)uploadFile:(NSArray<id<FTReadableFile>>*)files parameters:(NSDictionary *)parameters{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t uploadWork = ^{
        @autoreleasepool {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if(files.count == 0){
                [strongSelf scheduleNextCycle];
                return;
            }
            NSMutableArray<id<FTReadableFile>>*mutableFiles = [[NSMutableArray alloc]initWithArray:files];
            id<FTReadableFile> file = [mutableFiles firstObject];
            [mutableFiles removeObject:file];
            
            FTBatch *batch = [strongSelf.fileReader readBatch:file];
            if(batch){
                if([strongSelf flushWithEvent:batch.events parameters:parameters]){
                    [strongSelf.requestBuilder.classSerialGenerator increaseRequestSerialNumber];
                    if(mutableFiles.count == 0){
                        [strongSelf.delay decrease];
                    }
                    [strongSelf.fileReader markBatchAsRead:batch];
                }else{
                    [strongSelf.delay increase];
                    [strongSelf scheduleNextCycle];
                    return;
                }
            }
            if(mutableFiles.count == 0){
                [strongSelf scheduleNextCycle];
            }else{
                [strongSelf uploadFile:mutableFiles parameters:parameters];
            }
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
#pragma mark upload
-(BOOL)flushWithEvent:(id)event parameters:(NSDictionary *)parameters{
    @try {
        __block BOOL success = NO;
        __weak typeof(self) weakSelf = self;
        dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
        [self.requestBuilder requestWithEvents:event parameters:parameters];
        [self.httpClient sendRequest:self.requestBuilder completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                dispatch_semaphore_signal(flushSemaphore); 
                return;
            }
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"[NETWORK][%@] %@", strongSelf.featureName,[NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
                success = NO;
            }else{
                NSInteger statusCode = httpResponse.statusCode;
                success = (statusCode >= 200 && statusCode < 500);
                FTInnerLogDebug(@"[NETWORK][%@] Upload Response statusCode : %ld",strongSelf.featureName,(long)statusCode);
                if (statusCode != 200 && data.length>0) {
                    FTInnerLogError(@"[NETWORK][%@] Server exception, try again later responseData = %@",strongSelf.featureName,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                }
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
    [self.uploadConditions cancel];
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if(strongSelf.uploadWork){
            dispatch_block_cancel(strongSelf.uploadWork);
            strongSelf.uploadWork = nil;
        }
        if(strongSelf.readWork){
            dispatch_block_cancel(strongSelf.readWork);
            strongSelf.readWork = nil;
        }
    });
}
@end

@interface FTImageFeatureUpload()
@property (nonatomic, strong) FTResourceCheckRequest *checkRequest;

@end

@implementation FTImageFeatureUpload

-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                       cacheWriter:(id<FTCacheWriter>)cacheWriter
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance
                           context:(nonnull NSDictionary *)context{
    self = [super initWithFeatureName:featureName fileReader:fileReader cacheWriter:cacheWriter requestBuilder:requestBuilder maxBatchesPerUpload:maxBatchesPerUpload performance:performance context:context];
    if (self) {
        self.checkRequest = [[FTResourceCheckRequest alloc]init];
    }
    return self;
}

-(BOOL)flushWithEvent:(id)event parameters:(NSDictionary *)parameters{
    @try {
        NSMutableArray<FTEnrichedResource *> *resources = [NSMutableArray new];
        NSMutableArray *files = [NSMutableArray new];
        for (NSData *data in event) {
            FTEnrichedResource *resource = [[FTEnrichedResource alloc]initWithData:data];
            [resources addObject:resource];
            [files addObject:resource.identifier];
        }
        NSDictionary *content = [self checkImageWithEvent:files parameters:@{FT_APP_ID:resources[0].appId}];
        if (content == nil || content.count == 0) {
            return NO;
        }
        NSMutableArray *uploadResources = [NSMutableArray new];
        for (FTEnrichedResource *resource in resources) {
            NSNumber *fileExist = content[resource.identifier];
            if (fileExist && ![fileExist boolValue]) {
                [uploadResources addObject:resource];
            }
        }
        if (uploadResources.count == 0) {
            return YES;
        }
        return [super flushWithEvent:uploadResources  parameters:parameters];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
    return YES;
}

- (NSDictionary *)checkImageWithEvent:(id)event parameters:(NSDictionary *)parameters{
    __weak typeof(self) weakSelf = self;
    __block NSDictionary *content = nil;
    dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
    [self.checkRequest requestWithEvents:event parameters:parameters];
    [self.httpClient sendRequest:self.checkRequest completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            dispatch_semaphore_signal(flushSemaphore);
            return;
        }
        if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
            FTInnerLogError(@"[NETWORK][%@] %@", strongSelf.featureName,[NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
        }else{
            NSInteger statusCode = httpResponse.statusCode;
            FTInnerLogDebug(@"[NETWORK][%@] CheckImage Response statusCode : %ld",strongSelf.featureName,(long)statusCode);
            if (statusCode != 200 && data.length>0) {
                FTInnerLogError(@"[NETWORK][%@] Server exception, responseData: %@",strongSelf.featureName,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }else{
                NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:dataStr];
                content = dict[@"content"];
            }
        }
        dispatch_semaphore_signal(flushSemaphore);
    }];
    dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
    return content;
}
@end
