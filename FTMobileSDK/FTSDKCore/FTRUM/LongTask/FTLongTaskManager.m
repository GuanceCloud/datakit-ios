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
#import "FTRUMContext.h"

static NSString *const kSDKDirName      = @"com.ft.sdk";

#define FT_ANR_VERSION @"2.0.0"

#define FTBoundary  @"\n___boundary.info.date___\n"

#define FT_ANR_THRESHOLD_S 3 * 1e9
#define FT_ANR_THRESHOLD_UPDATE_S 149

@interface FTLongTaskEvent:NSObject
@property (nonatomic, assign) BOOL isANR;
@property (nonatomic, assign) BOOL isLongTask;
@property (nonatomic, assign) long long freezeDurationNs;
@property (nonatomic, assign) long long startDate;
@property (nonatomic, assign) long long lastDate;
@property (nonatomic, assign) long long duration;
@property (nonatomic, copy) NSString *mainThreadBacktrace;
@property (nonatomic, copy) NSString *allThreadsBacktrace;
@property (nonatomic, strong) FTFatalErrorContextModel *errorContextModel;
@property (nonatomic, assign) BOOL writeInFile;
@end
@implementation FTLongTaskEvent
-(instancetype)initWithFreezeDurationMs:(long)freezeDurationMs{
    self = [super init];
    if(self){
        _freezeDurationNs = (long long)freezeDurationMs*1000000;
        _isANR = NO;
        _isLongTask = NO;
    }
    return self;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    self = [super init];
    if (self) {
        self.isANR = [dict[@"isANR"] boolValue];
        self.startDate = [dict[@"startDate"] longLongValue];
        self.mainThreadBacktrace = dict[@"mainThreadBacktrace"];
        self.allThreadsBacktrace = dict[@"allThreadsBacktrace"];
        self.duration = [dict[@"duration"] longLongValue];
        self.errorContextModel = [[FTFatalErrorContextModel alloc]initWithDict:dict[@"errorContextModel"]];
    }
    return self;
}
-(void)setStartDate:(long long)startDate{
    _startDate = startDate;
}
-(void)setLastDate:(long long)lastDate{
    _lastDate = lastDate;
    _duration = _lastDate - self.startDate;
    if(_duration > FT_ANR_THRESHOLD_NS ){
        _isANR = YES;
    }
    if (_duration > _freezeDurationNs) {
        _isLongTask = YES;
    }
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:[NSNumber numberWithBool:self.isANR] forKey:@"isANR"];
    [dict setValue:@(self.startDate) forKey:@"startDate"];
    [dict setValue:self.mainThreadBacktrace forKey:@"mainThreadBacktrace"];
    [dict setValue:self.allThreadsBacktrace forKey:@"allThreadsBacktrace"];
    [dict setValue:@(self.duration) forKey:@"duration"];
    [dict setValue:[self.errorContextModel toDictionary] forKey:@"errorContextModel"];
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
@property (nonatomic, weak) id<FTBacktraceReporting> backtraceReporting;
@end
@implementation FTLongTaskManager
-(instancetype)initWithDependencies:(FTRUMDependencies *)dependencies
                           delegate:(id<FTRunloopDetectorDelegate>)delegate
                 backtraceReporting:(id<FTBacktraceReporting>)backtraceReporting
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
        _queue = dispatch_queue_create("com.ft.read-write", 0);
        dispatch_queue_set_specific(_queue, FTLongTaskManagerQueueTag, &FTLongTaskManagerQueueTag, NULL);
        _longTaskDetector = [[FTLongTaskDetector alloc]initWithDelegate:self];
        _backtraceReporting = backtraceReporting;
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
- (NSString *)dataStorePath {
    if (!_dataStorePath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *appSupportDir = [[fileManager URLsForDirectory:[self supportedDirectory] inDomains:NSUserDomainMask] firstObject];
        NSURL *sdkDirectory = [appSupportDir URLByAppendingPathComponent:kSDKDirName];

        if (![fileManager fileExistsAtPath:sdkDirectory.path]) {
            [fileManager createDirectoryAtURL:sdkDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        NSURL *fileURL = [sdkDirectory URLByAppendingPathComponent:@"longtask.log"];
        
#if TARGET_OS_IOS
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_TV
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#else
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
#endif
        NSString *oldPath = [docPath stringByAppendingPathComponent:@"FTLongTask.txt"];
        
        if ([fileManager fileExistsAtPath:oldPath]) {
            NSError *moveError = nil;
            [fileManager removeItemAtPath:oldPath error:&moveError];
        }
        _dataStorePath = fileURL.path;
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
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf)  return;
            NSError *error = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:strongSelf.dataStorePath];
            if(fileExists){
                [fileManager removeItemAtPath:strongSelf.dataStorePath error:&error];
                if(error){
                    FTInnerLogError(@"[LongTask] delete file：%@ fail. reason: %@",strongSelf.dataStorePath,error.description);
                }
            }else{
                FTInnerLogDebug(@"[LongTask] delete file: %@ is not exist",strongSelf.dataStorePath);
            }
            strongSelf.fileHandle = nil;
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
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if(!strongSelf) return;
            NSError *error;
            if (@available(macOS 10.15, iOS 13.0,tvOS 13.0, *)) {
                [strongSelf.fileHandle writeData:data error:&error];
                if(error){
                    FTInnerLogError(@"[LongTask] writeData error %@",error.description);
                }
            } else {
                [strongSelf.fileHandle writeData:data];
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
        long long errorDate = 0;
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        @try {
            NSError *error = nil;
            NSString *content = [NSString stringWithContentsOfFile:strongSelf.dataStorePath encoding:NSUTF8StringEncoding error:&error];
            if(error){
                goto ended;
            }
            //Has data, need to distinguish between longtask and anr
            if(content && content.length>0){
                NSArray *datas = [content componentsSeparatedByString:FTBoundary];
                if(datas.count != 3){
                    goto ended;
                }
                NSString *version = datas[0];
                if (![version isEqualToString:FT_ANR_VERSION]) {
                    goto ended;
                }

                NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:datas[1]];
                if (!dict) {
                    goto ended;
                }
                NSArray *updateTimes = [datas[2] componentsSeparatedByString:@"\n"];
                FTLongTaskEvent *event = [[FTLongTaskEvent alloc]initWithDictionary:dict];
                long long startTime = event.startDate;
                __block long long lastTime = 0;
                [updateTimes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(obj.length>0){
                        lastTime = [obj longLongValue];
                        *stop = YES;
                    }
                }];
                long long duration = lastTime-startTime > 0 ? lastTime - startTime : event.duration;
                if(duration <= 0){
                    goto ended;
                }
                BOOL isAnr = duration > 5 * 1e9;
                NSDictionary *tags = [event.errorContextModel.lastSessionState sessionTags];
                NSString *backtrace = event.mainThreadBacktrace;
    
                NSMutableDictionary *fields = [NSMutableDictionary dictionary];
                [fields setValue:@(duration) forKey:FT_DURATION];
                [fields setValue:event.mainThreadBacktrace forKey:FT_KEY_LONG_TASK_STACK];
                //Update View
                NSDictionary *lastViews  = event.errorContextModel.lastViewContext;
                BOOL sessionOnError = event.errorContextModel.lastSessionState.sampled_for_error_session;
                if(sessionOnError && isAnr){
                    [fields setValue:@(startTime) forKey:FT_SESSION_ERROR_TIMESTAMP];
                }
                if(lastViews){
                    NSMutableDictionary *lastViewsFields = [NSMutableDictionary dictionaryWithDictionary:lastViews[@"fields"]];
                    if (isAnr) {
                        lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] = @([lastViewsFields[FT_KEY_VIEW_ERROR_COUNT] intValue]+1);
                    }
                    lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] = @([lastViewsFields[FT_KEY_VIEW_LONG_TASK_COUNT] intValue]+1);
                    lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] = @([lastViewsFields[FT_KEY_VIEW_UPDATE_TIME] intValue]+1);
                    lastViewsFields[FT_KEY_IS_ACTIVE] = @(NO);
                    NSNumber *time = lastViews[@"time"];
                    
                    [strongSelf.dependencies.writer rumWrite:FT_RUM_SOURCE_VIEW tags:lastViews[@"tags"] fields:lastViewsFields time:[time longLongValue] updateTime:errorDate cache:sessionOnError];
                }
                [strongSelf.dependencies.writer rumWrite:FT_RUM_SOURCE_LONG_TASK tags:tags fields:fields time:startTime updateTime:0 cache:sessionOnError];
                
                //Determine if it's ANR, if so add ANR data
                if(isAnr){
                    NSString *allBacktrace = event.allThreadsBacktrace;
                    NSMutableDictionary *anrTags = [NSMutableDictionary dictionary];
                    [anrTags setValue:@"anr_error" forKey:FT_KEY_ERROR_TYPE];
                    [anrTags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
                    [anrTags setValue:event.errorContextModel.appState forKey:FT_KEY_ERROR_SITUATION];
                    [anrTags addEntriesFromDictionary:event.errorContextModel.errorMonitorInfo];
                    [anrTags addEntriesFromDictionary:event.errorContextModel.globalAttributes];
                    [anrTags addEntriesFromDictionary:event.errorContextModel.dynamicContext];
                    [anrTags addEntriesFromDictionary:[event.errorContextModel.lastSessionState sessionTags]];

                    [anrTags addEntriesFromDictionary:tags];
                    NSMutableDictionary *anrFields = [NSMutableDictionary dictionary];
                    [anrFields addEntriesFromDictionary:[event.errorContextModel.lastSessionState sessionFields]];
                    [anrFields setValue:@"ios_anr" forKey:FT_KEY_ERROR_MESSAGE];
                    [anrFields setValue:allBacktrace?:backtrace forKey:FT_KEY_ERROR_STACK];
                    errorDate = startTime;
                    [strongSelf.dependencies.writer rumWriteAssembledData:FT_RUM_SOURCE_ERROR tags:anrTags fields:anrFields time:startTime];
                }
                goto ended;
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@",exception);
            goto ended;
        }
    ended:
        [strongSelf deleteFile];
        [strongSelf.dependencies.writer lastFatalErrorIfFound:errorDate];
        return;
    });
}
- (void)startLongTask:(NSDate *)startDate{
    @try {
        // If lastSessionContext is nil, the current session is not sampled.
        FTFatalErrorContextModel *currentContextModel = self.dependencies.fatalErrorContext.currentContextModel;
        if(!currentContextModel.lastSessionState){
            return;
        }
        FTLongTaskEvent *event = [[FTLongTaskEvent alloc]initWithFreezeDurationMs:_freezeDurationMs];
        event.errorContextModel = currentContextModel;
        event.startDate = [startDate ft_nanosecondTimeStamp];
        event.mainThreadBacktrace = [self.backtraceReporting generateMainThreadBacktrace];
        event.lastDate = event.startDate;
        event.isANR = NO;
        self.longTaskEvent = event;
    }@catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
- (void)updateLongTaskDate:(NSDate *)date{
    @try {
        if(!self.enableANR||!self.longTaskEvent||!date){
            return;
        }
        long long updateDate = [date ft_nanosecondTimeStamp];
        // Reduce I/O
        if (updateDate - self.longTaskEvent.startDate > FT_ANR_THRESHOLD_S) {
            if (!self.longTaskEvent.writeInFile){
                self.longTaskEvent.allThreadsBacktrace = [self.backtraceReporting generateAllThreadsBacktrace];
                FTFatalErrorContextModel *currentContextModel = [self.dependencies.fatalErrorContext currentContextModel];
                self.longTaskEvent.errorContextModel = [[FTFatalErrorContextModel alloc]initWithAppState:currentContextModel.appState lastSessionState:currentContextModel.lastSessionState lastViewContext:currentContextModel.lastViewContext dynamicContext:currentContextModel.dynamicContext globalAttributes:currentContextModel.globalAttributes errorMonitorInfo:[self.dependencies.errorMonitorInfoWrapper errorMonitorInfo]];
                NSDictionary *dict = [self.longTaskEvent convertToDictionary];
                NSString *jsonString = [FTJSONUtil convertToJsonDataWithObject:dict];
                if(jsonString){
                    NSString *version = [NSString stringWithFormat:@"%@%@",FT_ANR_VERSION,FTBoundary];
                    NSData *versionData = [version dataUsingEncoding:NSUTF8StringEncoding];
                    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    NSData *boundaryData = [FTBoundary dataUsingEncoding:NSUTF8StringEncoding];
                    [self appendData:versionData];
                    [self appendData:data];
                    [self appendData:boundaryData];
                    self.longTaskEvent.writeInFile = YES;
                }else{
                    FTInnerLogError(@"[LongTask] longTaskEvent convert to Json Data Error");
                }
            }
            if(updateDate - self.longTaskEvent.lastDate > FT_ANR_THRESHOLD_UPDATE_S){
                self.longTaskEvent.lastDate = updateDate;
                NSString *lastDate = [NSString stringWithFormat:@"%lld\n",updateDate];
                NSData *data = [lastDate dataUsingEncoding:NSUTF8StringEncoding];
                [self appendData:data];
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
- (void)endLongTask{
    @try {
        if(!self.longTaskEvent){
            return;
        }
        self.longTaskEvent.lastDate = [NSDate ft_currentNanosecondTimeStamp];
        if(self.longTaskEvent.isLongTask && self.enableFreeze && self.delegate && [self.delegate respondsToSelector:@selector(longTaskStackDetected:duration:time:)]){
            long long startTime = self.longTaskEvent.startDate;
            [self.delegate longTaskStackDetected:self.longTaskEvent.mainThreadBacktrace duration:self.longTaskEvent.duration time:startTime];
        }
        if(self.enableANR){
            [self deleteFile];
            if(self.longTaskEvent.isANR && self.delegate && [self.delegate respondsToSelector:@selector(anrStackDetected:appState:time:)]){
                [self.delegate anrStackDetected:self.longTaskEvent.allThreadsBacktrace?:self.longTaskEvent.mainThreadBacktrace appState:self.longTaskEvent.errorContextModel.appState time:self.longTaskEvent.startDate];
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@",exception);
    }
}
-(void)shutDown{
    [_longTaskDetector stopDetecting];
    _longTaskEvent = nil;
    [self deleteFile];
}
-(void)dealloc{
    if(_fileHandle) {
        @try {
            if (@available(macOS 10.15, iOS 13.0,tvOS 13.0, *)) {
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
- (NSSearchPathDirectory)supportedDirectory {
#if TARGET_OS_TV
  return NSCachesDirectory;
#else
  return NSApplicationSupportDirectory;
#endif
}
@end
