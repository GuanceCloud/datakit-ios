//
//  FTNetworkInfo.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkInfo : NSObject
+ (NSString *)getNetworkType;
+ (int)getNetSignalStrength;
+ (NSString *)getProxyHost;
@end

NS_ASSUME_NONNULL_END
