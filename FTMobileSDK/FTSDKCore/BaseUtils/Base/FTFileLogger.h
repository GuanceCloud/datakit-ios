//
//  FTFileLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTLog+Private.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTLogFileManager : NSObject
@property (nonatomic, copy, readwrite) NSString *logsDirectory;
@property (nonatomic, copy, readwrite) NSString *prefix;
@property (nonatomic, copy, readwrite) NSString *filePath;
@property (atomic, assign)  unsigned long long logFilesDiskQuota;

-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;
-(instancetype)initWithLogsFilePath:(NSString *)filePath;
@end
@interface FTLogFileInfo : NSObject
@property (nonatomic, strong, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSDictionary<NSFileAttributeKey, id> *fileAttributes;
@property (nonatomic, strong, nullable, readonly) NSDate *creationDate;
@property (nonatomic, strong, nullable, readonly) NSDate *modificationDate;
@property (nonatomic, assign, readonly) unsigned long long fileSize;
@property (nonatomic, assign, readonly) NSTimeInterval age;
@property (nonatomic, assign, readonly) BOOL isSymlink;
@property (nonatomic, assign, readwrite) BOOL isArchived;
+ (instancetype)logFileWithPath:(NSString *)aFilePath;
- (instancetype)initWithFilePath:(NSString *)aFilePath;
@end
/**
 Single file size limit 32MB
 Total disk usage limit 1G
 File addition and deletion logic: when single file size exceeds limit, add new log file for writing, when total file size exceeds limit, delete the oldest file
 */
@interface FTFileLogger : FTAbstractLogger
@property (atomic, readwrite, assign) unsigned long long maximumFileSize;
@property (nonatomic, copy, readwrite) NSString *logsDirectory;
/// Initialization method
/// - Parameter manager: File management object
-(instancetype)initWithLogFileManager:(FTLogFileManager *)manager;
@end

NS_ASSUME_NONNULL_END
