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
/**
 * autotrack  全埋点事件抓取 存储数据库
 */
- (void)trackBackground:(NSString *_Nonnull)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *_Nonnull)field withTrackType:(FTTrackType)trackType;
/**
 * autotrack  全埋点页面流程图抓取 存储数据库
 */
- (void)flowTrack:(NSString *_Nonnull)product traceId:(NSString *_Nonnull)traceId name:(NSString *_Nonnull)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration field:(nullable NSDictionary *)field withTrackType:(FTTrackType)trackType;
@end
#endif /* FTMobileAgent_Private_h */
