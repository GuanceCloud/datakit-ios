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
void *FTTmpCacheQueueIdentityKey = &FTTmpCacheQueueIdentityKey;

@interface FTTmpCacheManager()<FTMessageReceiver>
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, strong) id<FTWriter> realWriter;
@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, copy) NSString *currentFileID;
@end
@implementation FTTmpCacheManager
- (instancetype)initWithFeatureName:(NSString *)featureName realWriter:(id<FTWriter>)realWriter coreDirectory:(FTDirectory *)coreDirectory{
    self = [super init];
    if (self) {
        _realWriter = realWriter;
        NSString *cacheName = [featureName stringByAppendingString:@".cache"];
        NSString *serialLabel = [NSString stringWithFormat:@"com.guance.%@", cacheName];
        // 创建串行队列管理文件操作
        _fileQueue = dispatch_queue_create([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_fileQueue,FTTmpCacheQueueIdentityKey, &FTTmpCacheQueueIdentityKey, NULL);
        // 初始化数据存储目录
        [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        _cacheDirectory = [coreDirectory createSubdirectoryWithPath:cacheName];
        _currentFileID = [[NSUUID UUID] UUIDString];
        // 启动定时清理任务
        [self setupCleanupTimer];
    }
    return self;
}
#pragma mark - 数据存储
- (void)write:(NSData *)datas{
    [self write:datas forceNewFile:NO];
}
- (void)write:(NSData *)datas forceNewFile:(BOOL)update{
    if(update){
        self.currentFileID = [[NSUUID UUID] UUIDString];
    }
    NSDate *timestamp = [NSDate date];
    [self saveData:datas withDate:timestamp];
}
- (NSString *)fileNameForTimestamp:(NSDate *)timestamp{
    // 按分钟分片：yyyyMMddHHmm
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmm";
    NSString *timeBucket = [formatter stringFromDate:timestamp];
    return [NSString stringWithFormat:@"%@_%@",timeBucket,self.currentFileID];
}
- (void)active{
    [[FTModuleManager sharedInstance] addMessageReceiver:self];
}
- (void)inactive{
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
}
- (void)receive:(NSString *)key message:(NSDictionary *)message{
    if ([key isEqualToString:FTMessageKeyRumError]){
        NSDate *date = [message valueForKey:@"error_date"];
        BOOL isCrash = [[message valueForKey:@"error_crash"] boolValue];
        [[FTModuleManager sharedInstance] postMessage:FTMessageKeySessionHasReplay message:@{FT_SESSION_HAS_REPLAY:@(YES)} sync:isCrash];
        [self handleErrorCommandWithTime:date shouldCacheTime:isCrash];
    }
}
- (void)saveData:(NSData *)data withDate:(NSDate *)timestamp{
    NSString *fileName = [self fileNameForTimestamp:timestamp];
    dispatch_async(_fileQueue, ^{
        // 获取对应分片文件路径
        FTFile *file = [self.cacheDirectory fileWithName:fileName];
        if(!file){
            file = [self.cacheDirectory createFile:fileName];
        }
        // 数据格式：时间戳,Base64内容\n
        NSString *entry = [NSString stringWithFormat:@"%f,%@\n",
                           [timestamp timeIntervalSince1970],
                           [data base64EncodedStringWithOptions:0]];
        [file append:[entry dataUsingEncoding:NSUTF8StringEncoding]];
    });
}
#pragma mark - 清理过期文件
- (void)setupCleanupTimer {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _fileQueue);
    dispatch_source_set_timer(timer,
                             DISPATCH_TIME_NOW,
                             60 * NSEC_PER_SEC, // 每分钟检查一次
                             0);
    dispatch_source_set_event_handler(timer, ^{
        NSDate *now = [NSDate date];
        NSDate *expirationDate = [now dateByAddingTimeInterval:-60];
        
        NSEnumerator *enumerator = [self.cacheDirectory.files objectEnumerator];
        FTFile *file;
        
        while ((file = [enumerator nextObject])) {
            // 从文件名解析时间分片
            NSDate *fileDate = [self dateFromFileName:file.name];
            // 删除过期文件
            if (fileDate && [fileDate compare:expirationDate] == NSOrderedAscending) {
                [file deleteFile];
            }
        }
    });
    dispatch_resume(timer);
}
- (NSDate *)dateFromFileName:(NSString *)fileName {
    NSString *minuteStr = [[fileName componentsSeparatedByString:@"_"] firstObject];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmm";
    return [formatter dateFromString:minuteStr];
}
#pragma mark - 处理指令a
- (void)handleErrorCommandWithTime:(NSDate *)aTime shouldCacheTime:(BOOL)cache{
    dispatch_block_t block = ^{
        NSMutableArray *eligibleFiles = [NSMutableArray array];
        
        // 步骤1: 收集需要处理的文件
        NSEnumerator *enumerator = self.cacheDirectory.files.objectEnumerator;
        FTFile *file;
        while ((file = [enumerator nextObject])) {
            NSDate *fileDate = [self dateFromFileName:file.name];
            if (fileDate && [fileDate compare:aTime] == NSOrderedAscending) {
                [eligibleFiles addObject:file];
            }
        }
        // 步骤2: 处理每个文件
        for (FTFile *file in eligibleFiles) {
            BOOL force = YES;
            NSError *error;
            NSString *content = [NSString stringWithContentsOfFile:file.url.path
                                                          encoding:NSUTF8StringEncoding
                                                             error:&error];
            if (!content || error) continue;
            
            NSMutableArray *remainingEntries = [NSMutableArray array];
            NSArray *lines = [content componentsSeparatedByString:@"\n"];

            // 逐行处理数据
            for (NSString *line in lines) {
                if (line.length == 0) continue;
                
                NSArray *components = [line componentsSeparatedByString:@","];
                if (components.count < 2) continue;
                
                // 解析时间戳
                NSTimeInterval timestamp = [components[0] doubleValue];
                NSDate *entryDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
                
                if ([entryDate compare:aTime] == NSOrderedAscending) {
                    // 写入目标文件
                    NSData *data = [[NSData alloc]initWithBase64EncodedString:components[1] options:0];
                    [self.realWriter write:data forceNewFile:force];
                    force = NO;
                } else {
                    [remainingEntries addObject:line];
                }
            }
            // 步骤4: 更新原文件
            if (remainingEntries.count > 0) {
                NSString *newContent = [remainingEntries componentsJoinedByString:@"\n"];
                [file write:[newContent dataUsingEncoding:NSUTF8StringEncoding]];
            } else {
                [file deleteFile];
            }
        }
    };
    if(cache){
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
