//
//  ZYInterceptor.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZYInterceptor : NSObject
+ (void)setup;

+ (void)registerAkId:(NSString *)aKId akSecret:(NSString *)akSecret;

@end

NS_ASSUME_NONNULL_END
