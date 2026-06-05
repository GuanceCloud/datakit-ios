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
#import "FTSessionReplayCoreImports.h"

void *FTTmpCacheQueueIdentityKey = &FTTmpCacheQueueIdentityKey;
static long long const FTErrorSampledCacheWindowNanoseconds = 60LL * 1000LL * 1000LL * 1000LL;

@interface FTTmpCacheManager()<FTMessageReceiver>
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSURL *realWriterUrl;
@property (nonatomic, strong) id<FTWriter> cacheWriter;

@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, copy) NSString *currentFileID;
// Force change file for writing
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
#pragma mark - Data Storage
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
        NSNumber *errorDate = [message valueForKey:@"error_date"];
        if (errorDate != nil) {
            [self consumeErrorSampledFilesBeforeErrorTime:[errorDate longLongValue] sync:NO];
        }
    }
}
#pragma mark - Clean Expired Files
#pragma mark ========== LAST PROCESS ==========
- (void)cleanupLastProcess{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        /// Check if there is error sampling for the previous process data, only do update operation
        long long lastErrorTimeStamp = [strongSelf.sessionOnErrorHandler getErrorTimeLineFromFileCache];
        long long processStartTimeStamp = [[FTDateUtil processStartTimestamp] ft_nanosecondTimeStamp];
        if(lastErrorTimeStamp>0){
            [strongSelf consumeErrorSampledFilesBeforeErrorTime:lastErrorTimeStamp sync:YES];
        }
        /// Previous process anr judgment, update\delete
        for (int i = 0; i <= 3; i++) {
            long long errorTimeStamp = [strongSelf.sessionOnErrorHandler getLastProcessFatalErrorTime];
            if (errorTimeStamp != -1 || i == 3) {
                if (errorTimeStamp > 0) {
                    [strongSelf consumeErrorSampledFilesBeforeErrorTime:errorTimeStamp sync:YES];
                }
                [strongSelf cleanupExpiredFilesBeforeTime:processStartTimeStamp sync:YES];
                break;
            }
            sleep(1);
        }
    });
}
#pragma mark ========== CURRENT PROCESS ==========
- (void)cleanup{
    long long expirationTimeStamp = [[[NSDate date] dateByAddingTimeInterval:-60] ft_nanosecondTimeStamp];
    [self cleanupExpiredFilesBeforeTime:expirationTimeStamp sync:NO];
}
- (void)consumeErrorSampledFilesBeforeErrorTime:(long long)errorTimeStamp sync:(BOOL)sync{
    if (errorTimeStamp <= 0) {
        return;
    }
    long long expirationTimeStamp = errorTimeStamp - FTErrorSampledCacheWindowNanoseconds;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            NSArray <FTFile *> *files = strongSelf.cacheDirectory.files;
            for (FTFile *file in files) {
                long long fileTimeStamp = [file.fileCreationDate ft_nanosecondTimeStamp];
                if (fileTimeStamp < expirationTimeStamp) {
                    [file deleteFile];
                    FTInnerLogDebug(@"[Session Replay][ErrorSampled] delete expire file: %@",file.name);
                } else if (fileTimeStamp < errorTimeStamp) {
                    [strongSelf moveCacheFileToRealDirectory:file];
                }
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay][Error Sampled] EXCEPTION: %@", exception.description);
        }
    };
    [self performCleanupBlock:block sync:sync];
}
- (void)cleanupExpiredFilesBeforeTime:(long long)expirationTimeStamp sync:(BOOL)sync{
    if (expirationTimeStamp <= 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            NSArray <FTFile *> *files = strongSelf.cacheDirectory.files;
            for (FTFile *file in files) {
                long long fileTimeStamp = [file.fileCreationDate ft_nanosecondTimeStamp];
                if (fileTimeStamp < expirationTimeStamp) {
                    [file deleteFile];
                    FTInnerLogDebug(@"[Session Replay][ErrorSampled] delete expire file: %@",file.name);
                }
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay][Error Sampled] EXCEPTION: %@", exception.description);
        }
    };
    [self performCleanupBlock:block sync:sync];
}
- (void)moveCacheFileToRealDirectory:(FTFile *)file{
    NSURL *destinationFileURL = [self.realWriterUrl URLByAppendingPathComponent:file.name];
    NSError *lastCriticalError = nil;
    [[NSFileManager defaultManager] moveItemAtURL:file.url toURL:destinationFileURL error:&lastCriticalError];
    FTInnerLogDebug(@"[Session Replay][ErrorSampled] consumeErrorSampledData: %@",file.name);
}
- (void)performCleanupBlock:(dispatch_block_t)block sync:(BOOL)sync{
    if (!block) {
        return;
    }
    if (sync) {
        block();
    }else{
        dispatch_async(_queue, block);
    }
}
@end
