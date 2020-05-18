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
 * autotrack  全埋点事件抓取 存储数据库
 */
- (void)trackBackground:(NSString *)measurement tags:(NSDictionary*)tags field:(NSDictionary *)field withTrackType:(FTTrackType)trackType;
/**
 * autotrack  全埋点页面流程图抓取 存储数据库
 */
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:( NSString *)parent tags:(NSDictionary *)tags duration:(long)duration field:(NSDictionary *)field withTrackType:(FTTrackType)trackType;
@end
#endif /* FTMobileAgent_Private_h */
