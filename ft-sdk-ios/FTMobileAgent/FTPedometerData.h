//
//  FTPedometerData.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTPedometerData : NSObject
/**
 *  步数
 */
@property(nonatomic, strong, nullable) NSNumber *numberOfSteps;
/**
 *  步行+跑步距离
 */
@property(nonatomic, strong, nullable) NSNumber *distance;
/**
 * 上楼
 */
@property(nonatomic, strong, nullable) NSNumber *floorsAscended;
/**
 * 下楼
 */
@property(nonatomic, strong, nullable) NSNumber *floorsDescended;
@end

NS_ASSUME_NONNULL_END
