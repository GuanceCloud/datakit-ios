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
 */
-(void)startWithConfig:(FTMobileConfig *)config;
/**
 * 移除全埋点
*/
-(void)remove;
- (NSString *)sdkTrackVersion;
@end

NS_ASSUME_NONNULL_END
