//
//  FTAutoTrack.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTMobileConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTAutoTrack : NSObject
/**
 * 启动全埋点
 * 建议：在 设置好全埋点是否开启 全埋点类型后 不要更改全埋点设置
 */
-(void)startWithConfig:(FTMobileConfig *)config;
@end

NS_ASSUME_NONNULL_END
