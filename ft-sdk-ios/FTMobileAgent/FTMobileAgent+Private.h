//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/14.
//  Copyright © 2020 hll. All rights reserved.
//

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTRecordModel;
/**
 埋点方式

 - FTTrackTypeCode: 主动埋点
 - FTTrackTypeAuto: SDK埋点
 */
typedef NS_ENUM(NSInteger, FTTrackType) {
    FTTrackTypeCode,
    FTTrackTypeAuto,
};

@interface FTMobileAgent (Private)
@property (nonatomic, strong,readonly) FTMobileConfig *config;

/**
 * 获取添加的页面描述字典
 * 如果 设置 isPageVtpDescEnabled 为NO return nil;
 */
- (NSDictionary *)getPageDescDict;
/**
 * 获取添加的视图树描述字典
 * 如果 设置 isPageVtpDescEnabled 为NO return nil;
*/
- (NSDictionary *)getVtpDescDict;
/**
 * 获取添加的页面描述字典 替换流程图
 * 如果 设置 isFlowChartDescEnabled 为NO return nil;
 */
- (NSDictionary *)getFlowChartDescDict;
/**
 * 获取设置的  isPageVtpDescEnabled 状态
 */
-(BOOL)getPageVtpDescEnabled;
/**
 * autotrack  全埋点事件抓取 存储数据库
 */
- (void)trackBackground:(NSString *)measurement tags:(NSDictionary*)tags field:(NSDictionary *)field withTrackType:(FTTrackType)trackType;
/**
 * autotrack  全埋点页面流程图抓取 存储数据库
 */
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:( NSString *)parent tags:(NSDictionary *)tags duration:(long)duration field:(NSDictionary *)field withTrackType:(FTTrackType)trackType;
/**
 * 提供给监控管理定时上传
*/
-(void)trackUpload:(NSArray<FTRecordModel *> *)list callBack:(void (^)(NSInteger statusCode,  id responseObject))callBack;
/**
 * 崩溃日志抓取
*/
- (void)exceptionWithopdata:(NSString *)content;
/**
 * 系统日志抓取
*/
- (void)traceConsoleLog:(NSString *)content;
@end
#endif /* FTMobileAgent_Private_h */
