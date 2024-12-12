//
//  FTLongTaskManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTLongTaskManager.h"
#import "FTLongTaskDetector.h"
#import "FTJSONUtil.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTFatalErrorContext.h"
#import "FTErrorMonitorInfo.h"
#import "FTLog+Private.h"
#define FTBoundary  @"\n___boundary.info.date___\n"
@interface FTLongTaskEvent:NSObject
@property (nonatomic, assign) BOOL isANR;
@property (nonatomic, assign) BOOL isLongTask;
@property (nonatomic, assign) long long freezeDurationNs;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, copy) NSString *backtrace;
@property (nonatomic, strong) NSDate *lastDate;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, copy) NSString *appState;
@property (nonatomic, strong) NSDictionary *view;
@property (nonatomic, strong) NSDictionary *sessionContext;
@property (nonatomic, strong) NSDictionary *errorMonitorInfo;
@end
@implementation FTLongTaskEvent
-(instancetype)initWithFreezeDurationMs:(int)freezeDurationMs{
    self = [super init];
    if(self){
        _freezeDurationNs = (long long)freezeDurationMs*1000000;
        _isANR = NO;
        _isLongTask = NO;
    }
    return self;
}
-(void)setStartDate:(NSDate *)startDate{
    _startDate = startDate;
    _duration = [_startDate ft_nanosecondTimeIntervalToDate:[NSDate date]];

}
-(void)setLastDate:(NSDate *)lastDate{
    _lastDate = lastDate;
    _duration = [self.startDate ft_nanosecondTimeIntervalToDate:_lastDate];
    if([_duration longLongValue] > FT_ANR_THRESHOLD_NS ){
        _isANR = YES;
    }
    if ([_duration longLongValue] > _freezeDurationNs) {
        _isLongTask = YES;
    }
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:[NSNumber numberWithBool:self.isANR] forKey:@"isANR"];
    [dict setValue:self.startDate?@([self.startDate ft_nanosecondTimeStamp]):nil forKey:@"startDate"];
    [dict setValue:self.backtrace forKey:@"backtrace"];
    [dict setValue:self.view forKey:@"view"];
    [dict setValue:self.sessionContext forKey:@"sessionContext"];
    [dict setValue:self.appState forKey:@"appState"];
    [dict setValue:self.errorMonitorInfo forKey:@"errorMonitorInfo"];
    [dict setValue:self.duration forKey:@"duration"];
    return dict;
}
@end
void *FTLongTaskManagerQueueTag = &FTLongTaskManagerQueueTag;
@interface FTLongTaskManager()<FTLongTaskProtocol>
@property (nonatomic, weak) id<FTRunloopDetectorDelegate> delegate;
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong) FTLongTaskDetector *longTaskDetector;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) FTLongTaskEvent *longTaskEvent;
@property (nonatomic, copy) NSString *dataStorePath;
@property (nonatomic, assign) BOOL enableANR;
@property (nonatomic, assign) BOOL enableFreeze;
@property (nonatomic, assign) long freezeDurationMs;
@end
@implementation FTLongTaskManager
-(instancetype)initWithDependencies:(FTRUMDependencies *)dependencies
                           delegate:(id<FTRunloopDetectorDelegate>)delegate
                  enableTrackAppANR:(BOOL)enableANR
               enableTrackAppFreeze:(BOOL)enableFreeze
                   freezeDurationMs:(long)freezeDurationMs
{
    self = [super init];
    if(self){
        _dependencies = dependencies;
        _delegate = delegate;
        _enableANR = enableANR;
        _enableFreeze = enableFreeze;
        _freezeDurationMs = freezeDurationMs;
        _queue = dispatch_queue_create("com.guance.read-write", 0);
        dispatch_queue_set_specific(_queue, FTLongTaskManagerQueueTag, &FTLongTaskManagerQueueTag, NULL);
        _longTaskDetector = [[FTLongTaskDetector alloc]initWithDelegate:self];
        _longTaskDetector.limitFreezeMillisecond = freezeDurationMs;
        [self reportFatalWatchDogIfFound];
        [_longTaskDetector startDetecting];
    }
    return self;
}
- (NSFileHandle *)fileHandle{
    if(!_fileHandle){
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self createFile]];
        @try {
            if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
                __autoreleasing NSError *error = nil;
                [_fileHandle seekToEndReturningOffset:nil error:&error];
                if (error) {
                    FTInnerLogError(@"[LongTask] error %@",error.description);
                }
            } else {
                [_fileHandle seekToEndOfFile];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@",exception);
        }
    }
    return _fileHandle;
}
- (NSString *)dataStorePath{
    if(!_dataStorePath){
        NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        _dataStorePath = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    }
    return _dataStorePath;
}
- (NSString *)createFile{
    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:self.dataStorePath]){
            return self.dataStorePath;
        }
        BOOL isSuccess = [fileManager createFileAtPath:self.dataStorePath contents:nil attributes:nil];
        if(isSuccess){
            return self.dataStorePath;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
    return nil;
}
- (void)deleteFile{
    __weak __typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        @try {
            NSError *error = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:weakSelf.dataStorePath];
            if(fileExists){
                [fileManager removeItemAtPath:weakSelf.dataStorePath error:&error];
                if(error){
                    FTInnerLogError(@"[LongTask] delete file：%@ fail. reason: %@",weakSelf.dataStorePath,error.description);
                }
            }else{
                FTInnerLogDebug(@"[LongTask] delete file: %@ is not exist",weakSelf.dataStorePath);
            }
            weakSelf.fileHandle = nil;
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@",exception);
        }
    };
    if (dispatch_get_specific(FTLongTaskManagerQueueTag)) {
        block();
    } else {
        dispatch_sync(self.queue, block);
    }
}
- (void)appendData:(NSData *)data{
    __weak __typeof(self) weakSelf = self;
    dispatch_async(_queue, ^{
        @try {
            NSError *error;
            if (@available(macOS 10.15, iOS 13.0, *)) {
                [weakSelf.fileHandle writeData:data error:&error];
                if(error){
                    FTInnerLogError(@"[LongTask] writeData error %@",error.description);
                }
            } else {
                [weakSelf.fileHandle writeData:data];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@",exception);
        }
    });
}
// longTask、 ANR、View
- (void)reportFatalWatchDogIfFound{
    __weak __typeof(self) weakSelf = self;
    dispatch_async(_queue, ^{
        @try {
            NSError *error = nil;
            NSString *content = [NSString stringWithContentsOfFile:weakSelf.dataStorePath encoding:NSUTF8StringEncoding error:&error];
            if(error){
                goto ended;
            }
            //有数据，需要区分是 longtask 还是 anr
            if(content && content.length>0){
                NSArray *datas = [content componentsSeparatedByString:FTBoundary];
                if(datas.count != 2){
                    goto ended;
                }
                NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:datas[0]];
                if (!dict) {
                    goto ended;
                }
                NSArray *updateTimes = [datas[1] componentsSeparatedByString:@"\n"];
                long long startTime = [dict[@"startDate"] longLongValue];
                __block long long lastTime = 0;
                [updateTimes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(obj.length>0){
                        lastTime = [obj longLongValue];
                        *stop = YES;
                    }
                }];
                NSNumber *duration = lastTime-startTime>0?[NSNumber numberWithLongLong:lastTime-startTime]:dict[@"duration"];
                if(!duration){
                    duration = @0;
                }
                NSDictionary *tags = dict[@"sessionContext"];
                NSString *backtrace = [dict valueForKey:@"backtrace"];
                if (!backtrace) {
                    backtrace = @"";
                }
                NSDictionary *fields = @{FT_DURATION:duration,
                                         FT_KEY_LONG_TASK_STACK:backtrace,
                };
                [weakSelf.dependencies.writer rumWrite:FT_RUM_SOURCE_LONG_TASK tags:tags fields:fields time:startTime];
                //判断是否是 ANR,是则添加 ANR 数据
                if(duration.longLongValue>5000000000){
                    NSMutableDictionary *anrTags = @{
                        FT_KEY_ERROR_TYPE:@"anr_error",
                        FT_KEY_ERROR_SOURCE:FT_LOGGER,
                    }.mutableCopy;
                    [anrTags setValue:dict[@"appState"] forKey:FT_KEY_ERROR_SITUATION];
                    [anrTags addEntriesFromDictionary:dict[@"errorMonitorInfo"]];
                    [anrTags addEntriesFromDictionary:tags];
                    NSMutableDictionary *field = @{ FT_KEY_ERROR_MESSAGE:@"ios_anr",
                                                    FT_KEY_ERROR_STACK:backtrace,
                    }.mutableCopy;
                    [weakSelf.dependencies.writer rumWrite:FT_RUM_SOURCE_ERROR tags:anrTags fields:field time:startTime];
                }
                //更新View
                NSDictionary *lastViews  = dict[@"view"];
                if(lastViews){
                    NSMutableDictionary *lastViewsFields = [NSMutableDictionary dictionaryWithDictionary:lastViews[@"fields"]];
                    lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] = @([lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] intValue]+1);
                    lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] = @([lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] intValue]+1);
                    lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] = @([lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] intValue]+1);
                    lastViewsFields[FT_KEY_IS_ACTIVE] = @(NO);
                    NSNumber *time = lastViews[@"time"];
                    [weakSelf.dependencies.writer rumWrite:FT_RUM_SOURCE_VIEW tags:lastViews[@"tags"] fields:lastViewsFields time:[time longLongValue]];
                }
                goto ended;
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@",exception);
            goto ended;
        }
    ended:
        [weakSelf deleteFile];
        return;
    });
}
- (void)startLongTask:(NSDate *)startDate backtrace:(NSString *)backtrace{
    @try {
        if(!self.dependencies.fatalErrorContext.lastSessionContext){
            return;
        }
        FTLongTaskEvent *event = [[FTLongTaskEvent alloc]initWithFreezeDurationMs:_freezeDurationMs];
        event.startDate = startDate;
        event.backtrace = backtrace;
        event.sessionContext = self.dependencies.fatalErrorContext.lastSessionContext;
        event.view = self.dependencies.fatalErrorContext.lastViewContext;
        event.isANR = NO;
        event.errorMonitorInfo = [FTErrorMonitorInfo errorMonitorInfo:self.dependencies.errorMonitorType];
        self.longTaskEvent = event;
        NSDictionary *dict = [self.longTaskEvent convertToDictionary];
        NSString *jsonString = [FTJSONUtil convertToJsonDataWithObject:dict];
        if(jsonString){
            NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            NSData *boundaryData = [FTBoundary dataUsingEncoding:NSUTF8StringEncoding];
            [self appendData:data];
            [self appendData:boundaryData];
        }else{
            FTInnerLogError(@"[LongTask] longTaskEvent convert to Json Data Error");
        }
    }@catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
- (void)updateLongTaskDate:(NSDate *)date{
    @try {
        if(!self.longTaskEvent||!date){
            return;
        }
        self.longTaskEvent.lastDate = date;
        long long updateDate = [date ft_nanosecondTimeStamp];
        NSString *lastDate = [NSString stringWithFormat:@"%lld\n",updateDate];
        NSData *data = [lastDate dataUsingEncoding:NSUTF8StringEncoding];
        [self appendData:data];
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
- (void)endLongTask{
    @try {
        if(!self.longTaskEvent){
            return;
        }
        self.longTaskEvent.lastDate = [NSDate date];
        if(self.longTaskEvent.isLongTask && self.enableFreeze && self.delegate && [self.delegate respondsToSelector:@selector(longTaskStackDetected:duration:time:)]){
            long long startTime = [self.longTaskEvent.startDate ft_nanosecondTimeStamp];
            [self.delegate longTaskStackDetected:self.longTaskEvent.backtrace duration:[self.longTaskEvent.duration longLongValue] time:startTime];
        }
        if(self.longTaskEvent.isANR){
            if(self.enableANR && self.delegate && [self.delegate respondsToSelector:@selector(anrStackDetected:time:)]){
                [self.delegate anrStackDetected:self.longTaskEvent.backtrace time:self.longTaskEvent.startDate];
            }
        }
        [self deleteFile];
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
-(void)shutDown{
    [_longTaskDetector stopDetecting];
    [self deleteFile];
}
-(void)dealloc{
    if(_fileHandle) {
        @try {
            if (@available(macOS 10.15, iOS 13.0, *)) {
                NSError *error;
                [_fileHandle synchronizeAndReturnError:&error];
                if(error){
                    FTNSLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", error.description);
                }
            }else{
                [_fileHandle synchronizeFile];
            }
        } @catch (NSException *exception) {
            FTNSLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", exception);
        }
    }
    if (_longTaskDetector) [_longTaskDetector stopDetecting];
}
@end
