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
@class FTRecordModel,FTUploadTool;
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
@property (nonatomic, strong) FTUploadTool *upTool;
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
 * logging 控制台日志 写入
*/
- (void)_loggingBackgroundInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm;
- (void)_loggingExceptionInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm;
- (void)_loggingArrayInsertDBImmediately;
/**
 * eventFlowLog、networkTrace 写入
*/
- (void)_loggingBackgroundInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm tags:(NSDictionary *)tags field:(NSDictionary *)field;
@end
#endif /* FTMobileAgent_Private_h */
