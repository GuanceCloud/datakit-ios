//
//  FTLocationManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/8.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTLocationManager.h"
#import <CoreLocation/CoreLocation.h>
#import "FTLog.h"
#import "FTConstants.h"
@interface FTLocationManager () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@end
@implementation FTLocationInfo
-(instancetype)init{
    if(self = [super init]){
        _city = FT_NULL_VALUE;
        _country = FT_NULL_VALUE;
        _province = FT_NULL_VALUE;
    }
    return self;
}
@end
@implementation FTLocationManager
static FTLocationManager *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
- (instancetype)init {
    if (self = [super init]) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = 200.0;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _location = [[FTLocationInfo alloc]init];
        _isUpdatingLocation = NO;
    }
    return self;
}
- (void)startUpdatingLocation{
    @try {
        //判断当前设备定位服务是否打开
        if (![CLLocationManager locationServicesEnabled]) {
            ZYDebug(@"设备尚未打开定位服务");
            return;
        }
        if (@available(iOS 8.0, *)) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        if (_isUpdatingLocation == NO) {
            [self.locationManager startUpdatingLocation];
            _isUpdatingLocation = YES;
        }
    }@catch (NSException *e) {
        ZYDebug(@"%@ error: %@", self, e);
    }
}
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *currentLocation = [locations lastObject];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocationCoordinate2D coordinate = currentLocation.coordinate;
    self.location.coordinate =coordinate;
    [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *array, NSError *error){
        if (error) {
            if (self.updateLocationBlock) {
                self.updateLocationBlock(self.location, error);
            }
            return;
        }
        if (array.count > 0){
            CLPlacemark *placemark = [array objectAtIndex:0];
            ZYDebug(@"%@",placemark.name);
            //获取城市
            NSString *province = placemark.administrativeArea;
            NSString *city = placemark.locality;
            NSString *country = placemark.country;
            if (!province){
                //四大直辖市的城市信息无法通过locality获得，只能通过获取省份的方法来获得（如果city为空，或province为空 则可知为直辖市）
                province =placemark.locality;
            }else if (!city) {
                //四大直辖市的城市信息无法通过locality获得，只能通过获取省份的方法来获得（如果city为空，则可知为直辖市）
                city = placemark.administrativeArea;
            }
            self.location.country = country;
            self.location.city = city;
            self.location.province = province;
            //暂时设置为APP一个生命周期内只需要获取一次
            if (self.updateLocationBlock) {
                self.updateLocationBlock(self.location, error);
            }
        }else if (error == nil && [array count] == 0){
            NSString *domain = @"com.ft.mobile.sdk.FTMobileAgent";
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:@"No results were returned."};
            NSError *error = [NSError errorWithDomain:domain
                                                 code:104
                                             userInfo:userInfo];
            ZYDebug(@"No results were returned.");
            if (self.updateLocationBlock) {
                self.updateLocationBlock(self.location, error);
            }
        }

    }];
    
}
- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    @try {
        if (self.updateLocationBlock) {
            self.updateLocationBlock(self.location, error);
        }
    }@catch (NSException * e) {
    }
}
- (void)stopUpdatingLocation{
    [self.locationManager stopUpdatingLocation];
}
- (BOOL)gpsServicesEnabled{
        if (([CLLocationManager locationServicesEnabled]) && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways || [CLLocationManager authorizationStatus] ==  kCLAuthorizationStatusAuthorizedWhenInUse)) {
        return YES;
    } else {
        return NO;
    }
}
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status)
    {
        case kCLAuthorizationStatusDenied:{                  // 拒绝授权
            ZYDebug(@"授权失败：用户拒绝授权或未开启定位服务");
            NSString *domain = @"com.ft.mobile.sdk.FTMobileAgent";
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:@"用户拒绝授权或未开启定位服务"};
            NSError *error = [NSError errorWithDomain:domain
                                                 code:104
                                             userInfo:userInfo];
            if (self.updateLocationBlock) {
                self.updateLocationBlock(self.location, error);
            }
        }
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:     // 在使用期间使用定位
            ZYDebug(@"授权成功：用户允许应用“使用期间”使用定位服务");
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            ZYDebug(@"授权成功：用户允许应用“始终”使用定位服务");    // 始终使用定位服务
            break;
        case kCLAuthorizationStatusNotDetermined:
            break;
        case kCLAuthorizationStatusRestricted:
            
            break;
    }
}
- (void)resetInstance{
    self.locationManager = nil;
    onceToken = 0;
    sharedInstance =nil;
}
@end
