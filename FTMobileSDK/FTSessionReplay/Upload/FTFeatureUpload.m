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
#import "FTUploadStatus.h"

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
@property (nonatomic, strong) FTUploadStatus *lastUploadStatus;
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
    dispatch_block_t readWorkItem = dispatch_block_create(0, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.cacheWriter cleanup];
        NSArray *conditions = [strongSelf.uploadConditions checkForUpload];
        if(conditions.count > 0){
            if([conditions containsObject:@"Upload URL Not Configured"]){
                FTInnerLogWarning(@"[NETWORK][%@] Upload blocked: Upload URL Not Configured",strongSelf.featureName);
            }else{
                FTInnerLogDebug(@"[NETWORK][%@] Upload skipped: %@",strongSelf.featureName,[conditions componentsJoinedByString:@" AND "]);
            }
            [strongSelf.delay increase];
            [strongSelf scheduleNextCycle];
            return;
        }
        //Read upload files
        NSArray<id <FTReadableFile>> *files = [strongSelf.fileReader readFiles:strongSelf.maxBatchesPerUpload];
        if(files == nil || files.count == 0){
            FTInnerLogDebug(@"[NETWORK][%@] No upload: No files to upload",strongSelf.featureName);
            [strongSelf.delay increase];
            [strongSelf scheduleNextCycle];
        }else{
            FTInnerLogDebug(@"[NETWORK][%@] Uploading batches... count:%lu",strongSelf.featureName,(unsigned long)files.count);
            [strongSelf uploadFile:files parameters:strongSelf.context];
        }
    });
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
    dispatch_block_t uploadWork = dispatch_block_create(0, ^{
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
                FTUploadStatus *uploadStatus = [strongSelf flushWithEvent:batch.events parameters:parameters];
                if(uploadStatus.success){
                    [strongSelf.requestBuilder.classSerialGenerator increaseRequestSerialNumber];
                    if(mutableFiles.count == 0){
                        [strongSelf.delay decrease];
                    }
                    FTInnerLogDebug(@"[NETWORK][%@] Upload succeeded: %@",strongSelf.featureName,uploadStatus.debugDescription);
                    strongSelf.lastUploadStatus = nil;
                    [strongSelf.fileReader markBatchAsRead:batch];
                }else{
                    strongSelf.lastUploadStatus = uploadStatus;
                    [strongSelf.delay increase];
                    FTInnerLogWarning(@"[NETWORK][%@] Upload failed, will retry: %@, next retry delay: %.3fs",strongSelf.featureName,uploadStatus.debugDescription,strongSelf.delay.current);
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
    });
    self.uploadWork = uploadWork;
    dispatch_async(self.queue, uploadWork);
}
- (void)scheduleNextCycle{
    if(self.readWork){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_delay.current * NSEC_PER_SEC)), self.queue, self.readWork);
    }
}
#pragma mark upload
-(FTUploadStatus *)flushWithEvent:(id)event parameters:(NSDictionary *)parameters{
    @try {
        __block FTUploadStatus *uploadStatus = nil;
        __weak typeof(self) weakSelf = self;
        dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
        [self.requestBuilder requestWithEvents:event parameters:parameters];
        [self.httpClient sendRequest:self.requestBuilder completion:^(NSHTTPURLResponse * _Nullable httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                dispatch_semaphore_signal(flushSemaphore); 
                return;
            }
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"[NETWORK][%@] %@", strongSelf.featureName,[NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
            }else{
                NSInteger statusCode = httpResponse.statusCode;
                FTInnerLogDebug(@"[NETWORK][%@] Upload Response statusCode : %ld",strongSelf.featureName,(long)statusCode);
                if (statusCode != 200 && data.length>0) {
                    FTInnerLogError(@"[NETWORK][%@] Server exception, try again later responseData = %@",strongSelf.featureName,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                }
            }
            uploadStatus = [FTUploadStatus statusWithHTTPResponse:httpResponse error:error previousStatus:strongSelf.lastUploadStatus];
            dispatch_semaphore_signal(flushSemaphore);
        }];
        dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
        return uploadStatus ?: [FTUploadStatus statusWithHTTPResponse:nil error:nil previousStatus:self.lastUploadStatus];
    }  @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }

    return [FTUploadStatus statusWithHTTPResponse:nil error:nil previousStatus:self.lastUploadStatus];
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

-(FTUploadStatus *)flushWithEvent:(id)event parameters:(NSDictionary *)parameters{
    @try {
        NSMutableArray<FTEnrichedResource *> *resources = [NSMutableArray new];
        for (NSData *data in event) {
            FTEnrichedResource *resource = [[FTEnrichedResource alloc]initWithData:data];
            if (resource) {
                [resources addObject:resource];
            }
        }
        if (resources.count == 0) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]initWithURL:[NSURL URLWithString:@"https://localhost"] statusCode:200 HTTPVersion:nil headerFields:nil];
            return [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:self.lastUploadStatus];
        }
        NSArray<NSArray<FTEnrichedResource *> *> *groupedResources = [self groupedResourcesByUploadContext:resources];
        for (NSUInteger idx = 0; idx < groupedResources.count; idx++) {
            NSArray<FTEnrichedResource *> *resourceGroup = groupedResources[idx];
            NSDictionary *groupParameters = [self parametersForResources:resourceGroup baseParameters:parameters];
            NSMutableArray<NSString *> *files = [NSMutableArray new];
            for (FTEnrichedResource *resource in resourceGroup) {
                [files addObject:resource.identifier];
            }
            NSDictionary *content = nil;
            FTUploadStatus *checkStatus = [self checkImageWithEvent:files parameters:groupParameters content:&content];
            if (content == nil || content.count == 0) {
                return checkStatus;
            }
            NSMutableArray<FTEnrichedResource *> *uploadResources = [NSMutableArray new];
            for (FTEnrichedResource *resource in resourceGroup) {
                NSNumber *fileExist = content[resource.identifier];
                if (fileExist && ![fileExist boolValue]) {
                    [uploadResources addObject:resource];
                }
            }
            if (uploadResources.count > 0) {
                FTUploadStatus *uploadStatus = [super flushWithEvent:uploadResources parameters:groupParameters];
                if (!uploadStatus.success) {
                    return uploadStatus;
                }
                if (idx < groupedResources.count - 1) {
                    [self.requestBuilder.classSerialGenerator increaseRequestSerialNumber];
                }
            }
            if (idx < groupedResources.count - 1) {
                [self.checkRequest.classSerialGenerator increaseRequestSerialNumber];
            }
        }
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]initWithURL:[NSURL URLWithString:@"https://localhost"] statusCode:200 HTTPVersion:nil headerFields:nil];
        return [FTUploadStatus statusWithHTTPResponse:response error:nil previousStatus:self.lastUploadStatus];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
    return [FTUploadStatus statusWithHTTPResponse:nil error:nil previousStatus:self.lastUploadStatus];
}

- (FTUploadStatus *)checkImageWithEvent:(id)event parameters:(NSDictionary *)parameters content:(NSDictionary **)content{
    __weak typeof(self) weakSelf = self;
    __block NSDictionary *responseContent = nil;
    __block FTUploadStatus *uploadStatus = nil;
    dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
    [self.checkRequest requestWithEvents:event parameters:parameters];
    [self.httpClient sendRequest:self.checkRequest completion:^(NSHTTPURLResponse * _Nullable httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            dispatch_semaphore_signal(flushSemaphore);
            return;
        }
        if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
            FTInnerLogError(@"[NETWORK][%@] %@", strongSelf.featureName,[NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
        }else{
            NSInteger statusCode = httpResponse.statusCode;
            if (statusCode < 200 || statusCode >= 500 || statusCode == 403 || statusCode == 429) {
                FTInnerLogError(@"[NETWORK][%@] CheckImage Response statusCode : %ld \n Server exception, responseData: %@",strongSelf.featureName,(long)statusCode,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }else{
                NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:dataStr];
                responseContent = dict[@"content"];
                FTInnerLogDebug(@"[NETWORK][%@] CheckImage Response statusCode : %ld \ncontent:%@",strongSelf.featureName,(long)statusCode,responseContent);
            }
        }
        NSError *statusError = error;
        if (!statusError && [httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = httpResponse.statusCode;
            BOOL isSuccessfulStatusCode = (statusCode >= 200 && statusCode < 500 && statusCode != 403 && statusCode != 429);
            if (isSuccessfulStatusCode && (responseContent == nil || responseContent.count == 0)) {
                statusError = [NSError errorWithDomain:@"FTSessionReplayUploadErrorDomain"
                                                  code:-1
                                              userInfo:@{NSLocalizedDescriptionKey:@"Resource check response content is empty"}];
            }
        }
        uploadStatus = [FTUploadStatus statusWithHTTPResponse:httpResponse error:statusError previousStatus:strongSelf.lastUploadStatus];
        dispatch_semaphore_signal(flushSemaphore);
    }];
    dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
    if (content) {
        *content = responseContent;
    }
    return uploadStatus ?: [FTUploadStatus statusWithHTTPResponse:nil error:nil previousStatus:self.lastUploadStatus];
}

- (NSArray<NSArray<FTEnrichedResource *> *> *)groupedResourcesByUploadContext:(NSArray<FTEnrichedResource *> *)resources{
    NSMutableArray<NSMutableArray<FTEnrichedResource *> *> *groups = [NSMutableArray new];
    for (FTEnrichedResource *resource in resources) {
        BOOL found = NO;
        for (NSMutableArray<FTEnrichedResource *> *group in groups) {
            FTEnrichedResource *groupSample = group.firstObject;
            if ([self isSameUploadContext:resource another:groupSample]) {
                [group addObject:resource];
                found = YES;
                break;
            }
        }
        if (!found) {
            [groups addObject:[NSMutableArray arrayWithObject:resource]];
        }
    }
    return [groups copy];
}

- (BOOL)isSameUploadContext:(FTEnrichedResource *)resource another:(FTEnrichedResource *)another{
    NSDictionary *bindInfo = resource.bindInfo ?: @{};
    NSDictionary *otherBindInfo = another.bindInfo ?: @{};
    BOOL sameBindInfo = [bindInfo isEqualToDictionary:otherBindInfo];
    BOOL sameAppID = (resource.appId == another.appId) || [resource.appId isEqualToString:another.appId];
    return sameBindInfo && sameAppID;
}

- (NSDictionary *)parametersForResources:(NSArray<FTEnrichedResource *> *)resources baseParameters:(NSDictionary *)baseParameters{
    FTEnrichedResource *resource = resources.firstObject;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:resource.appId forKey:FT_APP_ID];
    if (baseParameters) {
        [parameters addEntriesFromDictionary:baseParameters];
    }
    if (resource.bindInfo) {
        [parameters addEntriesFromDictionary:resource.bindInfo];
    }
    return [parameters copy];
}
@end
