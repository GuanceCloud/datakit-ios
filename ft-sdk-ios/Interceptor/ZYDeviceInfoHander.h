//
//  ZYDeviceInfoHander.h
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZYDeviceInfoHander : NSObject
+ (NSString *)getDeviceType;
+ (NSString *)getTelephonyInfo;
//+ (NSString *)getCarrierInfo;
+ (NSString *)resolution;
@end

NS_ASSUME_NONNULL_END
