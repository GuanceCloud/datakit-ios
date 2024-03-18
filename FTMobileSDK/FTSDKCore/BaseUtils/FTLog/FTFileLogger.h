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

@interface FTFileLogger : FTAbstractLogger
@property (nonatomic, copy, readwrite) NSString *logsDirectory;

/// 初始化方法，可以指定存储日志文件的文件夹路径。若未指定 logsDirectory ，那么将在应用程序的缓存目录中创建一个名为 'FTLogs' 的文件夹.
/// - Parameter filePath: 存储日志文件的文件夹
-(instancetype)initWithLogsDirectory:(nullable NSString *)logsDirectory;
@end

NS_ASSUME_NONNULL_END
