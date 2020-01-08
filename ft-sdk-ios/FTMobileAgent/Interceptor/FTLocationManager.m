//
//  FTGPSLocationConfig.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/8.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTLocationManager.h"
#import "ZYLog.h"
@interface FTLocationManager () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL isUpdatingLocation;
@end
@implementation FTLocationManager
- (instancetype)init {
    if (self = [super init]) {
        //默认设置设置精度为 100 ,也就是 100 米定位一次 ；准确性 kCLLocationAccuracyHundredMeters
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        // 设置过滤器为无
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
        self.locationManager.delegate = self;
    }
    return self;
}
- (void)startUpdatingLocation {
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

    [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *array, NSError *error){

    if (array.count > 0){

    CLPlacemark *placemark = [array objectAtIndex:0];

    //将获得的所有信息显示到label上

    ZYDebug(@"%@",placemark.name);

    //获取城市

    NSString *city = placemark.locality;

    if (!city) {

    //四大直辖市的城市信息无法通过locality获得，只能通过获取省份的方法来获得（如果city为空，则可知为直辖市）

    city = placemark.administrativeArea;

    }else if (error == nil && [array count] == 0){

    ZYDebug(@"No results were returned.");

    }else if (error != nil){
    
    ZYDebug(@"An error occurred = %@", error);

    }
        if (self.updateLocationBlock) {
            self.updateLocationBlock(city, error);
        }
    }
    }];
    [manager stopUpdatingLocation];
}
@end
