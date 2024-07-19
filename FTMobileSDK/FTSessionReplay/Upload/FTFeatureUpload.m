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
#import "FTTLV.h"
#import "FTFile.h"
#import "FTUploadConditions.h"
#import "FTSegmentJSON.h"
#import "FTDataStore.h"
NSString *const FT_IndexInView = @"ft-index-in-view";

@interface FTFeatureUpload()<NSCacheDelegate>{
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
@property (nonatomic, strong) FTUploadConditions *uploadConditions;
@property (nonatomic, strong) NSDictionary *context;
@property (nonatomic, copy) NSString *featureName;
@property (nonatomic, strong) NSMutableDictionary *indexInViews;
@property (nonatomic, strong) id<FTDataStore> dataStore;
@end
@implementation FTFeatureUpload
@synthesize readWork = _readWork;
@synthesize uploadWork = _uploadWork;

-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance 
                         dataStore:(id<FTDataStore>)dataStore
                           context:(nonnull NSDictionary *)context
{
    self = [super init];
    if(self){
        NSString *serialLabel = [NSString stringWithFormat:@"com.guance.%@-upload", featureName];
        _queue = dispatch_queue_create([serialLabel UTF8String], 0);
        _featureName = featureName;
        pthread_rwlock_init(&_readWorkLock, NULL);
        pthread_rwlock_init(&_uploadWorkLock, NULL);
        _dataStore = dataStore;
        _fileReader = fileReader;
        _requestBuilder = requestBuilder;
        _performance = performance;
        _context = context;
        _delay = [[FTDataUploadDelay alloc]initWithPerformance:performance];
        _maxBatchesPerUpload = maxBatchesPerUpload;
        _networkManager = [[FTNetworkManager alloc]initWithTimeoutIntervalForRequest:30];
        _uploadConditions = [[FTUploadConditions alloc]init];
        _indexInViews = [NSMutableDictionary new];
        [_uploadConditions startObserver];
        [self readKnownIndexInView];
    }
    return self;
}
- (void)readKnownIndexInView{
    __weak typeof(self) weakSelf = self;
    [self.dataStore valueForKey:FT_IndexInView callback:^(NSError *error, NSData *data, FTDataStoreKeyVersion version) {
        if(!error){
            if(version != DataStoreDefaultKeyVersion){
                FTInnerLogError(@"[Session Replay Upload] Resource Writer Read IndexInViews Error");
            }else if(data){
                NSError *error;
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if(dict){
                    [weakSelf.indexInViews addEntriesFromDictionary:dict];
                }
            }
        }else{
            FTInnerLogError(@"[Session Replay Upload] Resource Writer Read IndexInViews Error: %@",error.localizedDescription);
        }
        [weakSelf startReadWork];
    }];
}
- (void)startReadWork{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t readWorkItem = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        BOOL canUpload = [strongSelf.uploadConditions checkForUpload];
        //读取上传文件
        NSArray<id <FTReadableFile>> *files = canUpload?[strongSelf.fileReader readFiles:strongSelf.maxBatchesPerUpload]:nil;
        if(files == nil || files.count == 0){
            [strongSelf.delay increase];
            [strongSelf scheduleNextCycle];
        }else{
            FTInnerLogDebug(@"-----[%@] 开始上传 -----",strongSelf.featureName);
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
            if([strongSelf flushWithBath:batch parameters:parameters]){
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
// 不支持 resource 上传逻辑 需要重新适配
-(BOOL)flushWithBath:(FTBatch *)bath parameters:(NSDictionary *)parameters{
    NSArray *events = bath.events;
    events = [self mergeSegments:events];
    NSMutableArray *mutableEvents = [NSMutableArray arrayWithArray:events];
    for (FTSegmentJSON *record in events) {
        if([self flushWithEvent:record parameters:parameters]){
            [mutableEvents removeObject:record];
            NSLog(@"[SESSION REPLAY] %@",[record toJSONString]);
            [self cacheIndexInView:record.indexInView view:record.viewID];
        }else{
            NSMutableArray *tlvs = [NSMutableArray new];
            for (FTSRBaseFrame *record in mutableEvents) {
                NSData *data = [record toJSONData];
                FTTLV *tlv = [[FTTLV alloc]initWithType:1 value:data];
                [tlvs addObject:tlv];
            }
            bath.tlvDatas = tlvs;
            NSData *data = [bath serialize];
            NSError *error;
            [data writeToURL:bath.file.url options:NSDataWritingAtomic error:&error];
            return NO;
        }
    }
    return YES;
}
- (NSArray *)mergeSegments:(NSArray *)segments{
    NSMutableArray *ori = [NSMutableArray array];
    for (NSData *data in segments) {
        FTSegmentJSON *segment =  [[FTSegmentJSON alloc]initWithData:data];
        [ori addObject:segment];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSMutableDictionary<NSString*,NSNumber*> *indexes = [NSMutableDictionary new];
    for (int i=0; i<ori.count; i++) {
        FTSegmentJSON *segment = ori[i];
        if(indexes[segment.viewID] != nil){
            int idx = [indexes[segment.viewID] intValue];
            FTSegmentJSON *current = result[idx];
            [current mergeAnother:segment];
            result[idx] = current;
        }else{
            [indexes setValue:@(indexes.count) forKey:segment.viewID];
            [result addObject:segment];
            NSNumber *index = [self.indexInViews objectForKey:segment.viewID];
            segment.indexInView = index?@([index intValue] + 1):@(0);
        }
    }
    return result;
}
- (void)cacheIndexInView:(NSNumber *)index view:(NSString *)viewId{
    [self.indexInViews setValue:index forKey:viewId];
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{viewId:index} options:0 error:&error];
    if(data){
        [self.dataStore setValue:data forKey:FT_IndexInView version:DataStoreDefaultKeyVersion];
    }
}
#pragma mark upload
-(BOOL)flushWithEvent:(id)event parameters:(NSDictionary *)parameters{
    @try {
        __block BOOL success = NO;
        dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
        [self.requestBuilder requestWithEvent:event parameters:parameters];
        [self.networkManager sendRequest:self.requestBuilder completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"%@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
                success = NO;
                dispatch_semaphore_signal(flushSemaphore);
                return;
            }
            NSInteger statusCode = httpResponse.statusCode;
            success = (statusCode >=200 && statusCode < 500);
            FTInnerLogDebug(@"[NETWORK][session-replay] Upload Response statusCode : %ld",(long)statusCode);
            if (statusCode != 200 && data.length>0) {
                FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 responseData = %@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
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
