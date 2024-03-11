//
//  FTFileLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFileLogger.h"
#import "FTLogMessage.h"
#import "NSDate+FTUtil.h"

@interface FTFileLogger()
@property (nonatomic, strong) NSFileHandle *currentLogFileHandle;
@property (nonatomic, copy, readwrite) NSString *logsDirectory;

@end
@implementation FTFileLogger
-(instancetype)init{
    return [self initWithLogsDirectory:nil];
}
-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory{
    self = [super init];
    if(self){
        _loggerQueue = dispatch_queue_create("com.guance.debugLog.file", NULL);
        if(logsDirectory){
            _logsDirectory = [logsDirectory copy];
        }else{
            _logsDirectory = [[self defaultLogsDirectory] copy];
        }
    }
    return self;
}
- (NSString *)defaultLogsDirectory {

#if TARGET_OS_IPHONE
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"FTLogs"];
#else
    NSString *appName = [[NSProcessInfo processInfo] processName];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
    NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"FTLogs"] stringByAppendingPathComponent:appName];
#endif

    return logsDirectory;
}
- (NSFileHandle *)currentLogFileHandle {
    if (!_currentLogFileHandle) {
        NSString *logFilePath = [self currentLogFile];
        _currentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    }
    return _currentLogFileHandle;
}
- (NSString *)currentLogFile{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *filePath = [self.logsDirectory stringByAppendingPathComponent:@"FTLog.log"];
    BOOL fileExists = [manager fileExistsAtPath:filePath];
    if (fileExists) {
        return filePath;
    }
    NSError *error;
    BOOL directoryCreated = [manager createDirectoryAtPath:self.logsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    if (!directoryCreated) {
        FTNSLogError(@"[FTLog][FTFileLogger] FTFileLogger file created failed");
        return nil;
    }
    NSDictionary *attributes = nil;
#if TARGET_OS_IOS
    attributes = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
#endif
    BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:attributes];
    if (!fileCreated) {
        FTNSLogError(@"[FTLog][FTFileLogger] FTFileLogger file created failed");
        return nil;
    }
    return filePath;
}
- (void)logMessage:(nonnull FTLogMessage *)logMessage {
    if (!self.currentLogFileHandle) {
        FTNSLogError(@"[FTLog][FTFileLogger] %@ is not a valid file path.",_logsDirectory);
        return;
    }
    @try {
        NSData *data = [self dataForMessage:logMessage];
        if (data.length == 0) {
            return;
        }
        [self.currentLogFileHandle seekToEndOfFile];
        [self.currentLogFileHandle writeData:data];
    } @catch (NSException *exception) {
        FTNSLogError(@"[FTLog][FTFileLogger] %@",exception.description);
    }
}

- (NSData *)dataForMessage:(FTLogMessage *)logMessage{
    NSString *message = [self formatLogMessage:logMessage];
    if (message.length == 0) {
        return nil;
    }
    NSString *dateStr = [logMessage.timestamp ft_stringWithBaseFormat];
    message = [NSString stringWithFormat:@"%@ %@",dateStr,message];
    if (![message hasSuffix:@"\n"]) {
        message = [message stringByAppendingString:@"\n"];
    }
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}
@end
