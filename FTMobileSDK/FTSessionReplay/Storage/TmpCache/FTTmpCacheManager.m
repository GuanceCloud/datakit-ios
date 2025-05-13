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
#import "NSDate+FTUtil.h"
#import "FTLog+Private.h"

void *FTTmpCacheQueueIdentityKey = &FTTmpCacheQueueIdentityKey;

@interface FTTmpCacheManager()<FTMessageReceiver>
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, strong) NSURL *realWriterUrl;
@property (nonatomic, strong) id<FTWriter> cacheWriter;

@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, copy) NSString *currentFileID;
// 强制更换文件进行写入
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
        [self cleanupLastProcess];
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
        if (date) {
            long long expirationTimeStamp = [[date dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
            long long lastErrorTimeStamp = [date ft_nanosecondTimeStamp];
            [self cleanupWithExpirationTimeStamp:expirationTimeStamp lastErrorTimeStamp:lastErrorTimeStamp sync:isCrash];
        }
    }
}
#pragma mark - 清理过期文件
#pragma mark ========== LAST PROCESS ==========
- (void)cleanupLastProcess{
    /// 上一进程数据，仅做 update 操作
    long long lastErrorTimeStamp = [self.sessionOnErrorHandler getErrorTimeLineFromFileCache];
    if(lastErrorTimeStamp>0){
        [self cleanupWithExpirationTimeStamp:0 lastErrorTimeStamp:lastErrorTimeStamp sync:NO];
    }
    /// 上一进程 anr 判断，update\delete
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.fileQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        BOOL done = NO;
        NSInteger times = 0;
        while (done) {
            long long errorTimeStamp = [strongSelf.sessionOnErrorHandler getLastProcessFatalErrorTime];
            if (errorTimeStamp != -1 || times == 3) {
                done = YES;
                @try {
                    NSArray <FTFile *> *files = strongSelf.cacheDirectory.files;
                    NSEnumerator *enumerator = [files objectEnumerator];
                    FTFile *file;
                    while ((file = [enumerator nextObject])) {
                        // 从文件名解析时间分片
                        long long fileTimeStamp = [file.fileCreationDate ft_nanosecondTimeStamp];
                        // 发生在 error 之前产生的文件，移动到 upload
                        if (errorTimeStamp > 0 && errorTimeStamp > fileTimeStamp) {
                            NSURL *destinationFileURL = [strongSelf.realWriterUrl URLByAppendingPathComponent:file.name];
                            NSError *lastCriticalError = nil;
                            [[NSFileManager defaultManager] moveItemAtURL:file.url toURL:destinationFileURL error:&lastCriticalError];
                            continue;
                        }
                        // 上一进程产生的文件删除
                        if (fileTimeStamp < strongSelf.processStartTimeStamp) {
                            [file deleteFile];
                        }
                    }
                } @catch (NSException *exception) {
                    FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
                }
            }
            times ++;
            sleep(0.1);
        }
    });
}
#pragma mark ========== CURRENT PROCESS ==========
- (void)cleanup{
    long long expirationTimeStamp = [[[NSDate date] dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
    long long lastErrorTimeStamp = [self.sessionOnErrorHandler getErrorTimeLineFromFileCache];
    if (lastErrorTimeStamp < self.processStartTimeStamp ) lastErrorTimeStamp = 0;
    [self cleanupWithExpirationTimeStamp:expirationTimeStamp lastErrorTimeStamp:lastErrorTimeStamp sync:NO];
}
- (void)cleanupWithExpirationTimeStamp:(long long)expirationTimeStamp lastErrorTimeStamp:(long long)lastErrorTimeStamp sync:(BOOL)sync{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            NSArray <FTFile *> *files = strongSelf.cacheDirectory.files;
            NSEnumerator *enumerator = [files objectEnumerator];
            FTFile *file;
            while ((file = [enumerator nextObject])) {
                // 从文件名解析时间分片
                long long fileTimeStamp = [file.fileCreationDate ft_nanosecondTimeStamp];
                // 发生在 error 之前产生的文件，移动到 upload
                if (lastErrorTimeStamp > fileTimeStamp &&
                    (fileTimeStamp > strongSelf.processStartTimeStamp || lastErrorTimeStamp < self.processStartTimeStamp)) {
                    NSURL *destinationFileURL = [strongSelf.realWriterUrl URLByAppendingPathComponent:file.name];
                    NSError *lastCriticalError = nil;
                    [[NSFileManager defaultManager] moveItemAtURL:file.url toURL:destinationFileURL error:&lastCriticalError];
                    continue;
                }
                // 删除当前进程产生的已过期的文件
                if (expirationTimeStamp > 0 && fileTimeStamp > strongSelf.processStartTimeStamp &&
                    fileTimeStamp < expirationTimeStamp) {
                    [file deleteFile];
                }
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
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
