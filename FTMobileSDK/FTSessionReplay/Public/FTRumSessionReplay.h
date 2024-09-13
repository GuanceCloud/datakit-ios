//
//  FTRumSessionReplay.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSessionReplayConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTRumSessionReplay : NSObject

/// 单例
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());;

/// 配置 Config 开启 Session Replay
/// - Parameter config: Session Replay 配置项
- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config;
@end

NS_ASSUME_NONNULL_END
