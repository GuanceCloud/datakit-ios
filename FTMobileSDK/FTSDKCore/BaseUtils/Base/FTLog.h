//
//  FTLog.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// SDK internal debug logs
@interface FTLog : NSObject

/// Singleton
+ (instancetype)sharedInstance;

/// Write debug logs to the default file.
/// Documents/FTLogs/FTLog.log
- (void)registerInnerLogCacheToDefaultPath;

/// Write debug logs to file. If logsDirectory is not specified, a folder named 'FTLogs' will be created in the application's Documents. If fileNamePrefix is not specified, the log file prefix is 'FTLog'
/// - Parameters:
///   - logsDirectory: Folder to store log files
///   - fileNamePrefix: Log file name prefix
- (void)registerInnerLogCacheToLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;


/// Write debug logs to the specified file.
/// - Parameter filePath: Log file write path
///
/// Example:
/// ```
/// NSString *baseDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
/// NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"ExampleLogs"];
/// NSString *filePath = [logsDirectory stringByAppendingPathComponent:@"ExampleName.log"];
/// [[FTLog sharedInstance] registerInnerLogCacheToLogsFilePath:filePath];
/// ```
- (void)registerInnerLogCacheToLogsFilePath:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
