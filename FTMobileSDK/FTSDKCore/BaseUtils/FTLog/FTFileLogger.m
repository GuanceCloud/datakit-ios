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
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy, readwrite) NSString *logFilePath;

@end
@implementation FTFileLogger
-(instancetype)init{
    return [self initWithFilePath:nil];
}
-(instancetype)initWithFilePath:(NSString *)filePath{
    self = [super init];
    if(self){
        _logFilePath = filePath;
        _loggerQueue = dispatch_queue_create("com.guance.debugLog.file", NULL);
    }
    return self;
}
-(NSString *)logFilePath{
    if(!_logFilePath){
        _logFilePath = [self currentLogFile];
    }
    return _logFilePath;
}
- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
    }
    return _fileHandle;
}
- (NSString *)currentLogFile{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [path stringByAppendingPathComponent:@"FTLog/FTLog.log"];
    BOOL fileExists = [manager fileExistsAtPath:filePath];
    if (fileExists) {
        return filePath;
    }
    NSError *error;
    BOOL directoryCreated = [manager createDirectoryAtPath:[filePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
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
    if (!self.fileHandle) {
        FTNSLogError(@"[FTLog][FTFileLogger] %@ is not a valid file path.",_logFilePath);
        return;
    }
    @try {
        NSData *data = [self dataForMessage:logMessage];
        if (data.length == 0) {
            return;
        }
        [self.fileHandle seekToEndOfFile];
        [self.fileHandle writeData:data];
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
