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
@interface FTLocationInfo : NSObject
//国家
@property (nonatomic, copy) NSString *country;
//省
@property (nonatomic, copy) NSString *province;
//市
@property (nonatomic, copy) NSString *city;
//经纬度
@property (nonatomic, assign) CLLocationCoordinate2D  coordinate;
@end
@interface FTLocationManager : NSObject
@property (nonatomic, assign) BOOL isUpdatingLocation;
@property (nonatomic, strong) FTLocationInfo *location;
@property (nonatomic, copy) void(^updateLocationBlock)(FTLocationInfo *locInfo, NSError * _Nullable error);
+ (instancetype)sharedInstance;

- (void)startUpdatingLocation;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
