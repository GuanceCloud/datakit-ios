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

/// 将调试日志写入文件
/// - Parameter filePath: 缓存文件路径
- (void)registerInnerLogCacheToFile:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
