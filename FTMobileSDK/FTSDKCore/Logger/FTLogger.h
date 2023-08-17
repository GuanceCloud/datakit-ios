//
//  FTLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// 添加自定义日志接口协议
@protocol FTLoggerProtocol <NSObject>
@optional
/// 添加 info 类型自定义日志
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
-(void)info:(NSString *)content property:(nullable NSDictionary *)property;
/// 添加 warning 类型自定义日志
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
-(void)warning:(NSString *)content property:(nullable NSDictionary *)property;
/// 添加 error 类型自定义日志
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
-(void)error:(NSString *)content  property:(nullable NSDictionary *)property;
/// 添加 critical 类型自定义日志
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
-(void)critical:(NSString *)content property:(nullable NSDictionary *)property;
/// 添加 ok 类型自定义日志
/// - Parameters:
///   - content: 日志内容
///   - property: 自定义属性(可选)
-(void)ok:(NSString *)content property:(nullable NSDictionary *)property;

@end

/// 管理自定义日志
@interface FTLogger : NSObject<FTLoggerProtocol>
/// 单例
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());
/// 关闭 logger
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
