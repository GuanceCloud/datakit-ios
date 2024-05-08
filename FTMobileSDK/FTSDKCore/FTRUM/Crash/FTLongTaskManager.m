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
@interface FTLongTaskEvent:NSObject
@property (nonatomic, assign) BOOL isANR;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSString *backtrace;
@property (nonatomic, assign) NSDate *lastDate;
@property (nonatomic, assign) long long duration;
@property (nonatomic, strong) NSDictionary *view;
@end
@implementation FTLongTaskEvent
-(void)setLastDate:(NSDate *)lastDate{
    _lastDate = lastDate;
    _duration = [_lastDate ft_nanosecondTimeIntervalToDate:_startDate];
    if(_duration>5000000000){
        _isANR = YES;
    }
}
-(NSDictionary *)convertToDictionary{
    return @{@"isANR":@(self.isANR),
             @"startDate":self.startDate,
             @"backtrace":self.backtrace,
             @"view":self.view,
             @"lastDate":self.lastDate,
             @"duration":[NSNumber numberWithLongLong:self.duration],
    };
}
@end

@interface FTLongTaskManager()<FTLongTaskProtocol>
@property (nonatomic, weak) id<FTRunloopDetectorDelegate> delegate;
@property (nonatomic, weak) id<FTRUMDataWriteProtocol> writer;
@property (nonatomic, strong) FTLongTaskDetector *longTaskDetector;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) FTLongTaskEvent *longTaskEvent;
@property (nonatomic, assign) BOOL enableANR;
@property (nonatomic, assign) BOOL enableFreeze;
@end
@implementation FTLongTaskManager
-(instancetype)initWithDelegate:(id<FTRunloopDetectorDelegate>)delegate writer:(id<FTRUMDataWriteProtocol>)writer enableTrackAppANR:(BOOL)enableANR enableTrackAppFreeze:(BOOL)enableFreeze{
    self = [super init];
    if(self){
        _delegate = delegate;
        _enableANR = enableANR;
        _enableFreeze = enableFreeze;
        _longTaskDetector = [[FTLongTaskDetector alloc]initWithDelegate:self enableTrackAppANR:enableANR enableTrackAppFreeze:enableFreeze];
        [_longTaskDetector startDetecting];
        [self reportFatalWatchDogIfFound];
    }
    return self;
}
- (NSFileHandle *)fileHandle{
    if(!_fileHandle){
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self createFile]];
        if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
            __autoreleasing NSError *error = nil;
            [_fileHandle seekToEndReturningOffset:nil error:&error];
        } else {
            [_fileHandle seekToEndOfFile];
        }
    }
    return _fileHandle;
}
- (NSString *)createFile{
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:pathString]){
        return pathString;
    }
    NSError *error = nil;
    BOOL isSuccess = [fileManager createDirectoryAtPath:pathString withIntermediateDirectories:YES attributes:nil error:&error];
    if(isSuccess){
        return pathString;
    }
    return nil;
}
- (void)deleteFile{
    NSString *pathString = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    pathString = [pathString stringByAppendingPathComponent:@"FTLongTask.txt"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    [fileManager removeItemAtPath:pathString error:&error];
    if(_fileHandle) _fileHandle = nil;
}
- (void)reportFatalWatchDogIfFound{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self createFile];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    //有数据，需要区分是 longtask 还是 anr
    if(content && content.length>0){
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:content];
        long long startTime = [self.longTaskEvent.startDate ft_nanosecondTimeStamp];
        //添加 longtask 数据
        //[self.writer rumWrite:FT_RUM_SOURCE_LONG_TASK tags:@{} fields:@{} time:startTime];
        //判断是否是 ANR,是则添加 ANR 数据
        if(dict[@"isANR"]){
            //[self.writer rumWrite:FT_RUM_SOURCE_ERROR tags:@{} fields:@{} time:startTime];
        }
        //更新View
        //[self.writer rumWrite:FT_RUM_SOURCE_VIEW tags:@{} fields:@{} time:startTime];
        //删除本地保存文件
        [self deleteFile];
    }
    
}
- (void)startLongTask:(NSDate *)startDate backtrace:(NSString *)backtrace{
    FTLongTaskEvent *event = [[FTLongTaskEvent alloc]init];
    event.startDate = startDate;
    event.backtrace = backtrace;
    event.isANR = NO;
    self.longTaskEvent = event;
    NSDictionary *dict = [self.longTaskEvent convertToDictionary];
    NSString *jsonString = [FTJSONUtil convertToJsonData:dict];
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    [self.fileHandle writeData:data];
}
- (void)updateLongTaskDate:(NSDate *)date{
    self.longTaskEvent.lastDate = date;
}
- (void)endLongTask{
    self.longTaskEvent.lastDate = [NSDate date];
    if(self.enableFreeze && self.delegate && [self.delegate respondsToSelector:@selector(longTaskStackDetected:duration:time:)]){
        long long startTime = [self.longTaskEvent.startDate ft_nanosecondTimeStamp];
        [self.delegate longTaskStackDetected:self.longTaskEvent.backtrace duration:self.longTaskEvent.duration time:startTime];
    }
    if(self.longTaskEvent.isANR){
        if(self.enableANR && self.delegate && [self.delegate respondsToSelector:@selector(anrStackDetected:)]){
            [self.delegate anrStackDetected:self.longTaskEvent.backtrace];
        }
    }
    [self deleteFile];
}
-(void)dealloc{
    [_longTaskDetector stopDetecting];
}
@end
