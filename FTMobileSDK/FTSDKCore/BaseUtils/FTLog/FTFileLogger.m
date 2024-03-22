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
#import <sys/xattr.h>

unsigned long long const kFTDefaultLogMaxFileSize      = 100 * 1024 * 1024; // 100 MB
//NSUInteger         const kFTDefaultLogMaxNumLogFiles   = 10;
unsigned long long const kFTDefaultLogFilesDiskQuota   = 1 * 1024 * 1024 * 1024; // 1G

NSString * const FT_LOG_FILE_PREFIX = @"FTLog";
#if TARGET_OS_IPHONE
BOOL doesAppRunInBackground(void);
#endif
@interface FTLogFileManager()
@end
@implementation FTLogFileManager
-(instancetype)initWithLogsDirectory:(NSString *)logsDirectory fileNamePrefix:(NSString *)fileNamePrefix{
    self = [super init];
    if(self){
        _logFilesDiskQuota = kFTDefaultLogFilesDiskQuota;
//        _maximumNumberOfLogFiles = kFTDefaultLogMaxNumLogFiles;
        if(logsDirectory&&logsDirectory.length>0){
            _logsDirectory = [logsDirectory copy];
        }else{
            _logsDirectory = [[self defaultLogsDirectory] copy];
        }
        if(fileNamePrefix&&fileNamePrefix.length>0){
            _prefix = [fileNamePrefix copy];
        }else{
            _prefix = FT_LOG_FILE_PREFIX;
        }
    }
    return self;
}
// 默认的日志文件夹
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
- (NSString *)logsDirectory {
    __autoreleasing NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:_logsDirectory
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:&error];
    if (!success) {
        FTNSLogError(@"[FTLog][FTFileLogManager] Error creating logsDirectory: %@", error);
    }
    return _logsDirectory;
}
// 降序输出，新文件在队列前方，使用文件创建时间来排序
- (NSArray *)sortedLogFileInfos{
    return [[self unsortedLogFileInfos] sortedArrayUsingComparator:^NSComparisonResult(FTLogFileInfo *obj1,
                                                                                       FTLogFileInfo *obj2) {
        NSDate *date1 = [NSDate new];
        NSDate *date2 = [NSDate new];

        NSArray<NSString *> *arrayComponent = [[obj1 fileName] componentsSeparatedByString:@" "];
        if (arrayComponent.count > 0) {
            NSString *stringDate = arrayComponent.lastObject;
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".log" withString:@""];
            date1 = [obj1 creationDate];
        }

        arrayComponent = [[obj2 fileName] componentsSeparatedByString:@" "];
        if (arrayComponent.count > 0) {
            NSString *stringDate = arrayComponent.lastObject;
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".log" withString:@""];
            date2 = [obj2 creationDate];
        }

        return [date2 compare:date1 ?: [NSDate new]];
    }];
}
- (NSArray *)unsortedLogFileInfos{
    NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
    NSMutableArray *unsortedLogFileInfos = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
    for (NSString *filePath in unsortedLogFilePaths) {
        FTLogFileInfo *logFileInfo = [[FTLogFileInfo alloc] initWithFilePath:filePath];
        [unsortedLogFileInfos addObject:logFileInfo];
    }
    return unsortedLogFileInfos;
}

- (NSArray *)unsortedLogFilePaths{
    NSString *logsDirectory = [self logsDirectory];
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];
    NSMutableArray *unsortedLogFilePaths = [NSMutableArray arrayWithCapacity:[fileNames count]];
    for (NSString *fileName in fileNames) {
        // 判断文件是否为日志系统创建的，避免误处理用户创建的文件
        if ([self isLogFile:fileName])        {
            NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
            [unsortedLogFilePaths addObject:filePath];
        }
    }
    return unsortedLogFilePaths;
}
// 判断是否是SDK生成的日志文件
- (BOOL)isLogFile:(NSString *)fileName {
    NSString *prefix = _prefix;
    BOOL hasProperPrefix = [fileName hasPrefix:[prefix stringByAppendingString:@" "]];
    BOOL hasProperSuffix = [fileName hasSuffix:@".log"];
    return (hasProperPrefix && hasProperSuffix);
}
// 创建新的日志文件，命名格式："FTLog"+" "+"yyyy-MM-dd--HH:mm:ss:SSS"
- (NSString *)createNewLogFileWithError:(NSError *__autoreleasing  _Nullable *)error {
    static NSUInteger MAX_ALLOWED_ERROR = 5;
    NSDate *currentDate = [NSDate date];
    NSString *dateStr = [currentDate ft_stringWithBaseFormat];
    NSString *fileName = [NSString stringWithFormat:@"%@ %@.log",_prefix,dateStr];
    NSString *logsDirectory = [self logsDirectory];
    NSData *fileHeader = [NSData new];

    NSString *baseName = nil;
    NSString *extension;
    NSUInteger attempt = 1;
    NSUInteger criticalErrors = 0;
    NSError *lastCriticalError;

    if (error) *error = nil;
    do {
        if (criticalErrors >= MAX_ALLOWED_ERROR) {
            FTNSLogError(@"[FTLog][FTLogFileManager] : Bailing file creation, encountered %ld errors.",
                        (unsigned long)criticalErrors);
            if (error) *error = lastCriticalError;
            return nil;
        }
        NSString *actualFileName;
        if (attempt > 1) {
            if (baseName == nil) {
                baseName = [fileName stringByDeletingPathExtension];
                extension = [fileName pathExtension];
            }

            actualFileName = [baseName stringByAppendingFormat:@" %lu", (unsigned long)attempt];
            if (extension.length) {
                actualFileName = [actualFileName stringByAppendingPathExtension:extension];
            }
        } else {
            actualFileName = fileName;
        }

        NSString *filePath = [logsDirectory stringByAppendingPathComponent:actualFileName];

        __autoreleasing NSError *currentError = nil;
        BOOL success = [fileHeader writeToFile:filePath options:NSDataWritingAtomic error:&currentError];

#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
        if (success) {
            NSDictionary *attributes = @{NSFileProtectionKey: [self logFileProtection]};
            success = [[NSFileManager defaultManager] setAttributes:attributes
                                                       ofItemAtPath:filePath
                                                              error:&currentError];
        }
#endif

        if (success) {
            FTNSLogError(@"[FTLog][FTLogFileManager] Created new log file: %@", actualFileName);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self deleteOldLogFiles];
            });
            return filePath;
        } else if (currentError.code == NSFileWriteFileExistsError) {
            attempt++;
        } else {
            FTNSLogError(@"[FTLog][FTLogFileManager] Critical error while creating log file: %@", currentError);
            criticalErrors++;
            lastCriticalError = currentError;
        }
    } while (YES);
}
// 删除旧日志
- (void)deleteOldLogFiles {
    FTNSLogError(@"[FTLog][FTLogFileManager] deleteOldLogFiles");
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
    NSUInteger firstIndexToDelete = NSNotFound;
    unsigned long long used = 0;
    const unsigned long long diskQuota = _logFilesDiskQuota;
//    const NSUInteger maxNumLogFiles = _maximumNumberOfLogFiles;
    if(diskQuota){
        for (NSUInteger i = 0; i < sortedLogFileInfos.count; i++) {
            FTLogFileInfo *info = sortedLogFileInfos[i];
            used += info.fileSize;
            if (used > diskQuota) {
                firstIndexToDelete = i;
                break;
            }
        }
    }
//    if(maxNumLogFiles){
//        if (firstIndexToDelete == NSNotFound) {
//            firstIndexToDelete = maxNumLogFiles;
//        } else {
//            firstIndexToDelete = MIN(firstIndexToDelete, maxNumLogFiles);
//        }
//    }
    if (firstIndexToDelete == 0) {
        if (sortedLogFileInfos.count > 0) {
            FTLogFileInfo *logFileInfo = sortedLogFileInfos[0];
            if (!logFileInfo.isArchived) {
                ++firstIndexToDelete;
            }
        }
    }
    if (firstIndexToDelete != NSNotFound) {
        for (NSUInteger i = firstIndexToDelete; i < sortedLogFileInfos.count; i++) {
            FTLogFileInfo *logFileInfo = sortedLogFileInfos[i];

            __autoreleasing NSError *error = nil;
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:&error];
            if (success) {
                FTNSLogError(@"[FTLog] FTLogFileManager: Deleting file: %@", logFileInfo.fileName);
            } else {
                FTNSLogError(@"[FTLog] FTLogFileManager: Error deleting file %@", error);
            }
        }
    }
}
#if TARGET_OS_IPHONE
- (NSFileProtectionType)logFileProtection {
   if (doesAppRunInBackground()) {
        return NSFileProtectionCompleteUntilFirstUserAuthentication;
    } else {
        return NSFileProtectionCompleteUnlessOpen;
    }
}
#endif
@end
@interface FTFileLogger(){
    dispatch_source_t _currentLogFileVnode;
}
@property (nonatomic, strong) NSFileHandle *currentLogFileHandle;
@property (nonatomic, strong) FTLogFileInfo *currentLogFileInfo;
@property (nonatomic, strong) FTLogFileManager *logFileManager;
@end
@implementation FTFileLogger
-(instancetype)init{
    return [self initWithLogsDirectory:nil fileNamePrefix:nil];
}
-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix{
    return [self initWithLogFileManager:[[FTLogFileManager alloc]initWithLogsDirectory:logsDirectory fileNamePrefix:fileNamePrefix]];
}
-(instancetype)initWithLogFileManager:(FTLogFileManager *)manager{
    self = [super init];
    if(self){
        _maximumFileSize = kFTDefaultLogMaxFileSize;
        _loggerQueue = dispatch_queue_create("com.guance.debugLog.file", NULL);
        _logFileManager = manager;
    }
    return self;
}
- (NSFileHandle *)currentLogFileHandle {
    if (_currentLogFileHandle == nil) {
        NSString *logFilePath = [[self currentLogFileInfo] filePath];
        _currentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        if(_currentLogFileHandle != nil){
            if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
                __autoreleasing NSError *error = nil;
                BOOL success = [_currentLogFileHandle seekToEndReturningOffset:nil error:&error];
                if (!success) {
                    FTNSLogError(@"[FTLog][FTFileLogger] Failed to seek to end of file: %@", error);
                }
            } else {
                [_currentLogFileHandle seekToEndOfFile];
            }
            [self monitorCurrentLogFileForExternalChanges];
        }
    }
    return _currentLogFileHandle;
}

- (FTLogFileInfo *)currentLogFileInfo {
    FTLogFileInfo *newCurrentLogFile = _currentLogFileInfo;
    BOOL isResuming = newCurrentLogFile == nil;
    if (isResuming) {
        NSArray *sortedLogFileInfos = [self.logFileManager sortedLogFileInfos];
        newCurrentLogFile = sortedLogFileInfos.firstObject;
    }
    // 是否应用用当前的文件
    if (newCurrentLogFile != nil && [self shouldUseLogFile:newCurrentLogFile isResuming:isResuming]) {
        _currentLogFileInfo = newCurrentLogFile;
    } else {
        //创建新的日志文件
        NSString *currentLogFilePath;
        __autoreleasing NSError *error;
        currentLogFilePath = [self.logFileManager createNewLogFileWithError:&error];
        if (!currentLogFilePath) {
            FTNSLogError(@"[FTLog][FTFileLogger] Failed to create new log file: %@", error);
        }
        _currentLogFileInfo = [FTLogFileInfo logFileWithPath:currentLogFilePath];
    }

    return _currentLogFileInfo;
}
- (BOOL)shouldUseLogFile:(nonnull FTLogFileInfo *)logFileInfo isResuming:(BOOL)isResuming {
    if (![logFileInfo.fileName hasPrefix:self.logFileManager.prefix]){
        return NO;
    }
    if (logFileInfo.isArchived) {
        return NO;
    }
    if (logFileInfo.isSymlink) {
        return NO;
    }
    if (isResuming &&  [self shouldLogFileBeArchived:logFileInfo]) {
        logFileInfo.isArchived = YES;
        return NO;
    }
    return YES;
}
- (BOOL)shouldLogFileBeArchived:(FTLogFileInfo *)mostRecentLogFileInfo {
    if ( mostRecentLogFileInfo.fileSize >= _maximumFileSize) {
        return YES;
    }

#if TARGET_OS_IPHONE
    if (doesAppRunInBackground()) {
        NSFileProtectionType key = mostRecentLogFileInfo.fileAttributes[NSFileProtectionKey];
        BOOL isUntilFirstAuth = [key isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication];
        BOOL isNone = [key isEqualToString:NSFileProtectionNone];

        if (key != nil && !isUntilFirstAuth && !isNone) {
            return YES;
        }
    }
#endif
    return NO;
}
// 监控文件是否被外部操作
- (void)monitorCurrentLogFileForExternalChanges{
    _currentLogFileVnode = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                  (uintptr_t)[_currentLogFileHandle fileDescriptor],
                                                  DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE,
                                                  _loggerQueue);

    __weak __auto_type weakSelf = self;
    dispatch_source_set_event_handler(_currentLogFileVnode, ^{ @autoreleasepool {
        FTNSLogError(@"[FTLog][FTFileLogger] Current logfile was moved. Rolling it and creating a new one");
        [weakSelf rollLogFileNow];
    } });

#if !OS_OBJECT_USE_OBJC
    dispatch_source_t vnode = _currentLogFileVnode;
    dispatch_source_set_cancel_handler(_currentLogFileVnode, ^{
        dispatch_release(vnode);
    });
#endif

    dispatch_activate(_currentLogFileVnode);
}

- (void)logMessage:(nonnull FTLogMessage *)logMessage {
    @try {
        NSData *data = [self dataForMessage:logMessage];
        if (data.length == 0) {
            return;
        }
        NSFileHandle *fileHandle = self.currentLogFileHandle;
        if (@available(macOS 10.15, iOS 13.0, *)) {
            __autoreleasing NSError *error = nil;
            BOOL success = [fileHandle seekToEndReturningOffset:nil error:&error];
            if (!success) {
                FTNSLogError(@"[FTLog][FTFileLogger] Failed to seek to end of file: %@", error);
            }
            success =  [fileHandle writeData:data error:&error];
            if (!success) {
                FTNSLogError(@"[FTLog][FTFileLogger] Failed to write data: %@", error);
            }
        } else {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:data];
        }
        [self maybeRollLogFileDueToSize];
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
#pragma mark ========== File Rolling ==========
- (void)maybeRollLogFileDueToSize {
    if (_currentLogFileHandle != nil && _maximumFileSize > 0) {
        unsigned long long fileSize;
        if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
            __autoreleasing NSError *error = nil;
            BOOL success = [_currentLogFileHandle getOffset:&fileSize error:&error];
            if (!success) {
                FTNSLogError(@"[FTLog][FTFileLogger] Failed to get offset: %@", error);
                return;
            }
        } else {
            fileSize = [_currentLogFileHandle offsetInFile];
        }
        if (fileSize >= _maximumFileSize) {
            [self rollLogFileNow];
        }
    }
}
- (void)rollLogFileNow{
    if (_currentLogFileHandle == nil) {
        return;
    }
    if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
        __autoreleasing NSError *error = nil;
        BOOL success = [_currentLogFileHandle synchronizeAndReturnError:&error];
        if (!success) {
            FTNSLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", error);
        }
        success = [_currentLogFileHandle closeAndReturnError:&error];
        if (!success) {
            FTNSLogError(@"[FTLog][FTFileLogger] Failed to close file: %@", error);
        }
    } else {
        @try {
            [_currentLogFileHandle synchronizeFile];
        } @catch (NSException *exception) {
            FTNSLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", exception);
        }
        [_currentLogFileHandle closeFile];
    }
    _currentLogFileHandle = nil;
    _currentLogFileInfo.isArchived = YES;
    _currentLogFileInfo = nil;
}

@end

@interface FTLogFileInfo ()
@property (nonatomic, strong, readwrite) NSString *filePath;
@property (nonatomic, strong, readwrite) NSString *fileName;
@property (nonatomic, strong, readwrite) NSDictionary<NSFileAttributeKey, id> *fileAttributes;
@property (nonatomic, strong, nullable, readwrite) NSDate *creationDate;
@property (nonatomic, strong, nullable, readwrite) NSDate *modificationDate;
@property (nonatomic, assign, readwrite) unsigned long long fileSize;
@property (nonatomic, assign, readwrite) BOOL isSymlink;
@end
static NSString * const kFTXAttrArchivedName = @"FTSDK.log.archived";

@implementation FTLogFileInfo


#pragma mark Lifecycle

+ (instancetype)logFileWithPath:(NSString *)aFilePath {
    if (!aFilePath) return nil;
    return [[self alloc] initWithFilePath:aFilePath];
}

- (instancetype)initWithFilePath:(NSString *)aFilePath {
    NSParameterAssert(aFilePath);
    if ((self = [super init])) {
        _filePath = [aFilePath copy];
    }
    return self;
}
#pragma mark ========== Standard Info ==========
- (NSDictionary *)fileAttributes {
    if (_fileAttributes == nil && _filePath != nil) {
        __autoreleasing NSError *error = nil;
        _fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:&error];
        if (!_fileAttributes) {
            FTNSLogError(@"[FTLog][FTLogFileInfo] Failed to read file attributes: %@", error);
        }
    }
    return _fileAttributes ?: @{};
}

- (NSString *)fileName {
    if (_fileName == nil) {
        _fileName = [_filePath lastPathComponent];
    }
    return _fileName;
}
- (NSDate *)modificationDate {
    if (_modificationDate == nil) {
        _modificationDate = self.fileAttributes[NSFileModificationDate];
    }
    return _modificationDate;
}

- (NSDate *)creationDate {
    if (_creationDate == nil) {
        _creationDate = self.fileAttributes[NSFileCreationDate];
    }
    return _creationDate;
}

- (unsigned long long)fileSize {
    if (_fileSize == 0) {
        _fileSize = [self.fileAttributes[NSFileSize] unsignedLongLongValue];
    }
    return _fileSize;
}

- (NSTimeInterval)age {
    return -[[self creationDate] timeIntervalSinceNow];
}

- (BOOL)isSymlink {
    return self.fileAttributes[NSFileType] == NSFileTypeSymbolicLink;
}

- (NSString *)description {
    return [@{ @"filePath": self.filePath ? : @"",
               @"fileName": self.fileName ? : @"",
               @"fileAttributes": self.fileAttributes ? : @"",
               @"creationDate": self.creationDate ? : @"",
               @"modificationDate": self.modificationDate ? : @"",
               @"fileSize": @(self.fileSize),
               @"age": @(self.age),
               @"isArchived": @(self.isArchived) } description];
}

- (void)reset{
    _fileName = nil;
    _fileAttributes = nil;
    _creationDate = nil;
    _modificationDate = nil;
}
- (BOOL)isArchived{
    return [self hasExtendedAttributeWithName:kFTXAttrArchivedName];
}
- (void)setIsArchived:(BOOL)flag {
    if (flag) {
        [self addExtendedAttributeWithName:kFTXAttrArchivedName];
    } else {
        [self removeExtendedAttributeWithName:kFTXAttrArchivedName];
    }
}
- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [_filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];
    BOOL hasExtendedAttribute = NO;
    char buffer[1];

    ssize_t result = getxattr(path, name, buffer, 1, 0, 0);

    // Fast path
    if (result > 0 && buffer[0] == '\1') {
        hasExtendedAttribute = YES;
    }
    // Maintain backward compatibility, but fix it for future checks
    else if (result >= 0) {
        hasExtendedAttribute = YES;

        [self addExtendedAttributeWithName:attrName];
    }
    return hasExtendedAttribute;
}
- (void)addExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [_filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];
    int result = setxattr(path, name, "\1", 1, 0, 0);

    if (result < 0) {
        if (errno != ENOENT) {
            FTNSLogError(@"[FTLog][FTLogFileInfo] setxattr(%@, %@): error = %s",
                       attrName,
                       _filePath,
                       strerror(errno));
        } else {
            FTNSLogError(@"[FTLog][FTLogFileInfo] File does not exist in setxattr(%@, %@): error = %s",
                       attrName,
                       _filePath,
                       strerror(errno));
        }
    }
}
- (void)removeExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [_filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];

    int result = removexattr(path, name, 0);

    if (result < 0 && errno != ENOATTR) {
        FTNSLogError(@"[FTLog][FTLogFileInfo] removexattr(%@, %@): error = %s",
                   attrName,
                   self.fileName,
                   strerror(errno));
    }
}
@end

#if TARGET_OS_IPHONE
BOOL doesAppRunInBackground(void) {
    BOOL answer = NO;
    NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    for (NSString *mode in backgroundModes) {
        if (mode.length > 0) {
            answer = YES;
            break;
        }
    }
    return answer;
}

#endif
