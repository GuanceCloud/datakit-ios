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
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());;

- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config;
@end

NS_ASSUME_NONNULL_END
