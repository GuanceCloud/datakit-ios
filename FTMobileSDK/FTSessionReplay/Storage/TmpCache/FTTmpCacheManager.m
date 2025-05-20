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
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSURL *realWriterUrl;
@property (nonatomic, strong) id<FTWriter> cacheWriter;

@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, copy) NSString *currentFileID;
// 强制更换文件进行写入
@property (atomic, assign) BOOL hasErrorForceUpdate;
@property (nonatomic, weak) id<FTSessionOnErrorDataHandler> sessionOnErrorHandler;
@end
@implementation FTTmpCacheManager
- (instancetype)initWithCacheFileWriter:(id<FTWriter>)cacheWriter cacheDirectory:(FTDirectory *)cacheDirectory directory:(FTDirectory *)directory queue:(dispatch_queue_t)queue{
    self = [super init];
    if (self) {
        _sessionOnErrorHandler = [FTTrackDataManager sharedInstance].dataWriterWorker;
        _cacheWriter = cacheWriter;
        _cacheDirectory = cacheDirectory;
        _realWriterUrl = directory.url;
        _queue = queue;
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
        if (date) {
            long long expirationTimeStamp = [[date dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
            long long lastErrorTimeStamp = [date ft_nanosecondTimeStamp];
            [self cleanupWithExpirationTimeStamp:expirationTimeStamp lastErrorTimeStamp:lastErrorTimeStamp sync:NO];
        }
    }
}
#pragma mark - 清理过期文件
#pragma mark ========== LAST PROCESS ==========
- (void)cleanupLastProcess{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        /// 对上一进程数据判断是否有 error 采样，仅做 update 操作
        long long lastErrorTimeStamp = [self.sessionOnErrorHandler getErrorTimeLineFromFileCache];
        long long expirationTimeStamp = [[NSDate dateWithTimeIntervalSinceReferenceDate:FTAppLaunchTracker.processStartTime] ft_nanosecondTimeStamp];
        if(lastErrorTimeStamp>0){
            [strongSelf cleanupWithExpirationTimeStamp:0 lastErrorTimeStamp:lastErrorTimeStamp sync:YES];
        }
        /// 上一进程 anr 判断，update\delete
        for (int i = 0; i <= 3; i++) {
            long long errorTimeStamp = [strongSelf.sessionOnErrorHandler getLastProcessFatalErrorTime];
            if (errorTimeStamp != -1 || i == 3) {
                [strongSelf cleanupWithExpirationTimeStamp:expirationTimeStamp lastErrorTimeStamp:errorTimeStamp sync:YES];
                break;
            }
            sleep(1);
        }
    });
}
#pragma mark ========== CURRENT PROCESS ==========
- (void)cleanup{
    long long expirationTimeStamp = [[[NSDate date] dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
    long long lastErrorTimeStamp = [self.sessionOnErrorHandler getErrorTimeLineFromFileCache];
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
                if (lastErrorTimeStamp > fileTimeStamp) {
                    NSURL *destinationFileURL = [strongSelf.realWriterUrl URLByAppendingPathComponent:file.name];
                    NSError *lastCriticalError = nil;
                    [[NSFileManager defaultManager] moveItemAtURL:file.url toURL:destinationFileURL error:&lastCriticalError];
                    FTInnerLogError(@"[Session Replay][Error Sampled] consumeErrorSampledData: %@",file.name);
                    continue;
                }
                // 删除当前进程产生的已过期的文件
                if (expirationTimeStamp > 0 && fileTimeStamp < expirationTimeStamp) {
                    [file deleteFile];
                    FTInnerLogError(@"[Session Replay][Error Sampled] delete expire file: %@",file.name);
                }
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay][Error Sampled] EXCEPTION: %@", exception.description);
        }
    };
    if (sync) {
        block();
    }else{
        dispatch_async(_queue, block);
    }
}
@end
