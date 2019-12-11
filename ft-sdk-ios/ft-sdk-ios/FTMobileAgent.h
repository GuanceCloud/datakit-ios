//
//  ZYInterceptor.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTMobileConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileAgent : NSObject
+ (void)setup;

+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;
@end

NS_ASSUME_NONNULL_END
