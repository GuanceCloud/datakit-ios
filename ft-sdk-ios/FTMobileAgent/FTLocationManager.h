//
//  FTLocationManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/8.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTLocationManager : NSObject
@property (nonatomic, copy) void(^updateLocationBlock)(NSString *country,NSString *province, NSString *city, NSError *error);
- (void)startUpdatingLocation;
@end

NS_ASSUME_NONNULL_END
