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
@property (atomic, assign)  unsigned long long logFilesDiskQuota;

-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;
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
 单个文件大小限制 32MB
 总的磁盘占用限制 1G
 文件新增、删除逻辑：单个文件大小超过限制，新增新的日志文件写入，文件总大小超过限制时删除最旧的文件
 */
@interface FTFileLogger : FTAbstractLogger
@property (atomic, readwrite, assign) unsigned long long maximumFileSize;
@property (nonatomic, copy, readwrite) NSString *logsDirectory;

/// 初始化方法，可以指定存储日志文件的文件夹路径。若未指定 logsDirectory ，那么将在应用程序的缓存目录中创建一个名为 'FTLogs' 的文件夹.
/// - Parameters:
///   - logsDirectory: 保存日志的文件夹
///   - fileNamePrefix: 日志文件名前缀
-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;

/// 初始化方法
/// - Parameter manager: 文件管理对象
-(instancetype)initWithLogFileManager:(FTLogFileManager *)manager;
@end

NS_ASSUME_NONNULL_END
