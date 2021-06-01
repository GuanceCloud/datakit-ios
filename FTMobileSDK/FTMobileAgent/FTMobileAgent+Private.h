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
@class FTRecordModel,FTUploadTool,FTPresetProperty;
/**
 - FTAddDataNormal: 异步写入数据库
 - FTAddDataCache:  事务写入数据库
 - FTAddDataImmediate: 同步写入数据库
 */
typedef NS_ENUM(NSInteger, FTAddDataType) {
    FTAddDataNormal,
    FTAddDataCache,
    FTAddDataImmediate,
};


@interface FTMobileAgent (Private)
@property (nonatomic, assign) BOOL running; //正在运行
@property (nonatomic, strong,readonly) FTMobileConfig *config;
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTPresetProperty *presetProperty;

/**
 * 采集判断
 */
- (BOOL)judgeIsTraceSampling;
- (BOOL)judgeRUMTraceOpen;


- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

/**
 * eventFlowLog
*/
-(void)loggingWithType:(FTAddDataType)type status:(FTStatus)status content:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm;
/**
 * networkTrace 写入
 */
-(void)tracing:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm;


-(void)resetInstance;


@end
#endif /* FTMobileAgent_Private_h */
