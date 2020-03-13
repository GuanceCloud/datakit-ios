//
//  FTMobileAgent.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTTrackBean.h"
NS_ASSUME_NONNULL_BEGIN
//@interface FTTrackBean : NSObject
//@property (nonatomic, strong) NSString *measurement;
//@property (nonatomic, strong) NSDictionary *tags;
//@property (nonatomic, strong) NSDictionary *field;
//@property (nonatomic, strong) NSString *timeMillis;
//@end
@interface FTMobileAgent : NSObject
/**
 * @abstract
 * 返回之前所初始化好的单例
 *
 * @discussion
 * 调用这个方法之前，必须先调用 startWithConfigOptions 这个方法
 *
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;
/**
SDK 初始化方法

@param configOptions     配置参数
*/
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;
/**
 主动埋点，追踪自定义事件。 存储数据库，等待上传
 @param measurement      当前数据点所属的指标集
 @param field     自定义指标
*/
- (void)trackBackgroud:(NSString *)measurement  field:(NSDictionary *)field;
/**
 主动埋点，追踪自定义事件。 存储数据库，等待上传
 @param measurement      当前数据点所属的指标集
 @param tags       自定义标签
 @param field     自定义指标
 */
- (void)trackBackgroud:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field;
/**
 主动埋点，追踪自定义事件。  立即上传 回调上传结果
 @param measurement     当前数据点所属的指标集
 @param field           自定义指标
*/
- (void)trackImmediate:(NSString *)measurement  field:(NSDictionary *)field callBack:(void (^)(BOOL isSuccess))callBackStatus;
/**
主动埋点，追踪自定义事件。   立即上传 回调上传结果
@param measurement      当前数据点所属的指标集
@param tags             自定义标签
@param field            自定义指标
*/
- (void)trackImmediate:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field callBack:(void (^)(BOOL isSuccess))callBackStatus;
/**
主动埋点，可多条上传。   立即上传 回调上传结果
@param trackList     主动埋点数据数组   如果FTTrackBean 中timeMillis 传入格式错误，会自动赋值当前时间
*/
- (void)trackImmediateList:(NSArray <FTTrackBean *>*)trackList callBack:(void (^)(BOOL isSuccess))callBackStatus;
/**
 上报流程图
 @param product   指标集 命名只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
 @param traceId   标示一个流程单的唯一 ID
 @param name      流程节点名称
 @param parent    当前流程节点的上一个流程节点的名称，如果是流程的第一个节点，可不上报
 @param tags      自定义标签
 @param duration  流程单在当前流程节点滞留时间或持续时间，毫秒为单位
 @param field     自定义指标
*/
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration field:(nullable NSDictionary *)field;
/**
 上报流程图
 @param product   指标集 命名只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
 @param traceId   标示一个流程单的唯一 ID
 @param name      流程节点名称
 @param parent    当前流程节点的上一个流程节点的名称，如果是流程的第一个节点，可不上报
 @param duration  流程单在当前流程节点滞留时间或持续时间，毫秒为单位
*/
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(nullable NSString *)parent duration:(long)duration;
/**
绑定用户信息
 @param name      用户名
 @param Id        用户Id
 @param exts      用户其他信息
*/
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(nullable NSDictionary *)exts;
/**
 注销当前用户
*/
- (void)logout;
@end

NS_ASSUME_NONNULL_END
