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
@property (nonatomic, assign) BOOL running; //正在运行
@property (nonatomic, strong,readonly) FTMobileConfig *config;
@property (nonatomic, strong) FTUploadTool *upTool;
/**
 * 采集判断
 */
- (BOOL)judgeIsTraceSampling;
/**
 * 数据采集
 * type : InfluxDB指标集
 */
- (void)track:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

- (void)track:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

- (void)trackES:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

- (void)trackES:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

-(void)trackStartWithViewLoadTime:(CFTimeInterval)time;
/**
 * eventFlowLog、networkTrace 写入
*/
- (void)_loggingBackgroundInsertWithOP:(NSString *)op status:(NSString *)status content:(NSString *)content tm:(long long)tm tags:(NSDictionary *)tags field:(NSDictionary *)field;
/**
 * 崩溃日志写入
*/
- (void)_loggingExceptionInsertWithContent:(NSString *)content tm:(long long)tm;

@end
#endif /* FTMobileAgent_Private_h */
