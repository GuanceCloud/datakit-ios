//
//  FTTmpCacheManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/19.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTTmpCacheManager.h"
#import "FTDirectory.h"
#import "FTFile.h"
#import "FTModuleManager.h"
#import "FTConstants.h"
#import "FTMessageReceiver.h"
#import "FTUploadProtocol.h"
#import "FTTrackDataManager.h"
#import "FTAppLaunchTracker.h"

void *FTTmpCacheQueueIdentityKey = &FTTmpCacheQueueIdentityKey;

@interface FTTmpCacheManager()<FTMessageReceiver>
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, strong) NSURL *realWriterUrl;
@property (nonatomic, strong) id<FTWriter> cacheWriter;

@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, copy) NSString *currentFileID;
@property (atomic, assign) BOOL hasErrorForceUpdate;
@property (nonatomic, assign) long long processStartTimeStamp;
@property (nonatomic, weak) id<FTSessionOnErrorDataHandler> sessionOnErrorHandler;
@end
@implementation FTTmpCacheManager
- (instancetype)initWithCacheFileWriter:(id<FTWriter>)cacheWriter cacheDirectory:(FTDirectory *)cacheDirectory directory:(FTDirectory *)directory{
    self = [super init];
    if (self) {
        _processStartTimeStamp = [[NSDate dateWithTimeIntervalSinceReferenceDate:FTAppLaunchTracker.processStartTime] ft_nanosecondTimeStamp];
        _sessionOnErrorHandler = [FTTrackDataManager sharedInstance].dataWriterWorker;
        _cacheWriter = cacheWriter;
        _cacheDirectory = cacheDirectory;
        _realWriterUrl = directory.url;
        // 创建串行队列管理文件操作
        _fileQueue = dispatch_queue_create("com.guance.session-replay.cache", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_fileQueue,FTTmpCacheQueueIdentityKey, &FTTmpCacheQueueIdentityKey, NULL);
    }
    return self;
}
#pragma mark - 数据存储
- (void)write:(NSData *)datas{
    [self write:datas forceNewFile:NO];
}
- (void)write:(NSData *)datas forceNewFile:(BOOL)update{
    [self.cacheWriter write:datas forceNewFile:self.hasErrorForceUpdate?:update];
    self.hasErrorForceUpdate = NO;
}
- (void)active{
    [[FTModuleManager sharedInstance] addMessageReceiver:self];
}
- (void)inactive{
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
}
- (void)receive:(NSString *)key message:(NSDictionary *)message{
    if ([key isEqualToString:FTMessageKeyRumError]){
        self.hasErrorForceUpdate = YES;
        NSDate *date = [message valueForKey:@"error_date"];
        BOOL isCrash = [[message valueForKey:@"error_crash"] boolValue];
        [self cleanupWithDate:date sync:isCrash];
    }
}
#pragma mark - 清理过期文件
- (void)cleanup{
    [self cleanupWithDate:[NSDate date] sync:NO];
}
- (void)cleanupWithDate:(NSDate *)date sync:(BOOL)sync{
    dispatch_block_t block = ^{
        long long expirationTimeStamp = [[date dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
        long long lastErrorTimeStamp = [self.sessionOnErrorHandler getErrorTimeLineFromFileCache];
        
        NSArray <FTFile *> *files = self.cacheDirectory.files;
        NSEnumerator *enumerator = [files objectEnumerator];
        FTFile *file;
        while ((file = [enumerator nextObject])) {
            // 从文件名解析时间分片
            long long fileTimeStamp = [file.name longLongValue] * 1e6;
            // 发生在 error 之前产生的文件，移动到 upload
            if (lastErrorTimeStamp > fileTimeStamp &&
                (fileTimeStamp > self.processStartTimeStamp || lastErrorTimeStamp < self.processStartTimeStamp)) {
                NSURL *destinationFileURL = [self.realWriterUrl URLByAppendingPathComponent:file.name];
                NSError *lastCriticalError = nil;
                [[NSFileManager defaultManager] moveItemAtURL:file.url toURL:destinationFileURL error:&lastCriticalError];
                continue;
            }
            // 当前进程产生的文件
            if (fileTimeStamp > self.processStartTimeStamp &&
                fileTimeStamp < expirationTimeStamp) {
                [file deleteFile];
            }
        }
    };
    if (sync) {
        [self syncProcess:block];
    }else{
        dispatch_async(_fileQueue, block);
    }
}
- (void)syncProcess:(dispatch_block_t)block{
    if(dispatch_get_specific(FTTmpCacheQueueIdentityKey) == NULL){
        dispatch_sync(self.fileQueue, block);
    }else{
        block();
    }
}
@end
