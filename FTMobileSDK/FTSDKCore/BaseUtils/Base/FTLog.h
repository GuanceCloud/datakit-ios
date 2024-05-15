//
//  FTLog.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// SDK 内部调试日志
@interface FTLog : NSObject

/// 单例
+ (instancetype)sharedInstance;

/// 将调试日志写入默认文件。
/// Documents/FTLogs/FTLog.log
- (void)registerInnerLogCacheToDefaultPath;

/// 将调试日志写入文件。若未指定 logsDirectory ，那么将在应用程序的 Documents 中创建一个名为 'FTLogs' 的文件夹。若未指定 fileNamePrefix ，日志文件前缀为 'FTLog'
/// - Parameters:
///   - logsDirectory: 存储日志文件的文件夹
///   - fileNamePrefix: 日志文件名前缀
- (void)registerInnerLogCacheToLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;


/// 将调试日志写入指定文件。
/// - Parameter filePath: 日志写入文件路径
///
/// 示例：
/// ```
/// NSString *baseDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
/// NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"ExampleLogs"];
/// NSString *filePath = [logsDirectory stringByAppendingPathComponent:@"ExampleName.log"];
/// [[FTLog sharedInstance] registerInnerLogCacheToLogsFilePath:filePath];
/// ```
- (void)registerInnerLogCacheToLogsFilePath:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
