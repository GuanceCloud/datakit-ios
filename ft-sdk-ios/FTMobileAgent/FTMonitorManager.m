//
//  FTMonitorManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMonitorManager.h"
#import <CoreLocation/CLLocationManager.h>
#import <CoreBluetooth/CoreBluetooth.h>
#include <arpa/inet.h>
#include <resolv.h>
#include <dns.h>
#import <ifaddrs.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "FTLocationManager.h"
#import "ZYLog.h"
#import "FTBaseInfoHander.h"
#import "FTMobileConfig.h"
#import "FTNetworkInfo.h"
#import "FTNetMonitorFlow.h"
#import "FTGPUUsage.h"
#import "FTRecordModel.h"
#import "FTMobileAgent.h"
#import<CoreMotion/CoreMotion.h> //陀螺仪
#import "FTURLProtocol.h"

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *devicesListArray;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) CMMotionManager *motionManager;//陀螺仪
@property (nonatomic, assign) CMAcceleration acceleration;
@end
@implementation FTMonitorManager
-(instancetype)initWithConfig:(FTMobileConfig *)config{
    self = [super init];
    if (self) {
        self.devicesListArray = [NSMutableArray new];
        self.config = config;
        [self startMonitor];
    }
    return self;
}
-(void)setConfig:(FTMobileConfig *)config{
    _config = config;
    if (!(_config.monitorInfoType & FTMonitorInfoTypeAll) && !(_config.monitorInfoType &FTMonitorInfoTypeNetwork)) {
        [self.netFlow stopMonitor];
    }else{
        [self startFlushTimer];
    }
    if(_config.monitorInfoType & FTMonitorInfoTypeLocation || _config.monitorInfoType & FTMonitorInfoTypeAll){
        if ([[FTLocationManager sharedInstance].location.country isEqualToString:@"N/A"]) {
            [[FTLocationManager sharedInstance] startUpdatingLocation];
        }
    }
    [self startUpdateAccelerometerResult];
}
-(FTNetMonitorFlow *)netFlow{
    if (!_netFlow) {
        _netFlow = [FTNetMonitorFlow new];
    }
    return _netFlow;
}
//陀螺仪暂停
- (void)stopUpdate{
    if([self.motionManager isAccelerometerActive] == YES){
        [self.motionManager stopAccelerometerUpdates];
    }
}
- (void)startUpdateAccelerometerResult{//陀螺仪开始
    if([self.motionManager isAccelerometerAvailable] == YES){
        [self.motionManager setAccelerometerUpdateInterval:(double)self.config.flushInterval / 1000.0];
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error){
            if (!error) {
                self.acceleration = accelerometerData.acceleration;
            }
        }];
    }
}
-(void)flush{
    [[FTMobileAgent sharedInstance] trackImmediate:@"ios_device_monitor" field:[self getWifiAndIPAddress] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        
    }];
}
-(CMMotionManager*)motionManager {
    if (_motionManager == nil) {
        _motionManager= [[CMMotionManager alloc]init];
    }
    return _motionManager;
}
-(CGFloat)screenBrightness{
    return [UIScreen mainScreen].brightness;
}
-(NSDictionary *)monitorTagDict{
    if (!_monitorTagDict) {
        NSMutableDictionary *tag = [NSMutableDictionary new];
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        
        if (self.config.monitorInfoType &FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:@"battery_total"];
        }
        if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTBaseInfoHander ft_getTotalMemorySize] forKey:@"memory_total"];
        }
        if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:@"cpu_no"];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:@"cpu_hz"];
        }
        if(self.config.monitorInfoType &FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:@"gpu_model"];
        }
        if (self.config.monitorInfoType & FTMonitorInfoTypeCamera || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTBaseInfoHander ft_getFrontCameraPixel] forKey:@"camera_front_px"];
            [tag setObject:[FTBaseInfoHander ft_getBackCameraPixel] forKey:@"camera_back_px"];
        }
        _monitorTagDict = tag;
    }
    return _monitorTagDict;
}
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];
    // 动态数值类型 作为 field 类型
    if (self.config.enableAutoTrack) {
        [tag setObject:self.config.sdkTrackVersion forKey:@"autoTrack"];
    }
    if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithLong:[FTBaseInfoHander ft_cpuUsage]] forKey:@"cpu_use"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTBaseInfoHander ft_usedMemory]] forKey:@"memory_use"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        __block NSNumber *network_strength;
        __block NSString *network_type;
        if ([NSThread isMainThread]) { // do something in main thread } else { // do something in other
            network_type =[FTNetworkInfo getNetworkType];
            network_strength =[NSNumber numberWithInt:[FTNetworkInfo getNetSignalStrength]];
        }else{
            dispatch_sync(dispatch_get_main_queue(), ^{
                network_type =[FTNetworkInfo getNetworkType];
                network_strength = [NSNumber numberWithInt:[FTNetworkInfo getNetSignalStrength]];
            });
        }
        [tag setObject:network_type forKey:@"network_type"];
        [field setObject:network_strength forKey:@"network_strength"];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.iflow] forKey:@"network_in_rate"];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.oflow] forKey:@"network_out_rate"];
        
        if ([FTNetworkInfo getProxyHost]) {
            [tag setObject:[FTNetworkInfo getProxyHost] forKey:@"network_proxy"];
        }else{
            [tag setObject:@"N/A" forKey:@"network_proxy"];
        }
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTBaseInfoHander ft_getBatteryUse]] forKey:@"battery_use"];
        [field setObject:[NSNumber numberWithBool:[FTBaseInfoHander ft_batteryIsCharing]] forKey:@"battery_charing"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        double usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [field setObject:[NSNumber numberWithDouble:usage] forKey:@"gpu_rate"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag setValue:[FTLocationManager sharedInstance].location.province forKey:@"province"];
        [tag setValue:[FTLocationManager sharedInstance].location.city forKey:@"city"];
        [tag setValue:[FTLocationManager sharedInstance].location.country forKey:@"country"];
        [tag setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.latitude] forKey:@"latitude"];
        [tag setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.longitude] forKey:@"longitude"];
        
    }
    if([self.motionManager isAccelerometerAvailable] == YES){
//        [field setValue:[NSNumber numberWithDouble:self.acceleration.x] forKey:@"acceleration_x"];
//        [field setValue:[NSNumber numberWithDouble:self.acceleration.y] forKey:@"acceleration_y"];
//        [field setValue:[NSNumber numberWithDouble:self.acceleration.z] forKey:@"acceleration_z"];
    }
    
    return @{@"field":field,@"tag":tag};
}
#pragma mark --------- 实时网速 ----------
// 启动获取实时网络定时器
- (void)startFlushTimer {
    if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [self stopFlushTimer];
        [self.netFlow startMonitor];
    }
}
// 关闭获取实时网络定时器
- (void)stopFlushTimer {
    if (!_netFlow) {
        return;
    }
    [self.netFlow stopMonitor];
}
- (void)startMonitor{
 
    [FTURLProtocol startMonitor];
}
#pragma mark ========== 开机时间/自定义手机名称 ==========
//系统开机时间获取
- (long)getLaunchSystemTime{
    NSTimeInterval timer = [NSProcessInfo processInfo].systemUptime;
    NSDate *currentDate = [NSDate new];
    NSDate *startTime = [currentDate dateByAddingTimeInterval:(-timer)];
    NSTimeInterval convertStartTimeToSecond = [startTime timeIntervalSince1970];
    return convertStartTimeToSecond;
}
//用户自定义的手机名称
- (NSString *)userDeviceName{
    NSString * userPhoneName = [[UIDevice currentDevice] name];
    return userPhoneName;
}
#pragma mark ==========  dns ==========
- (NSDictionary *)getDNSInfo{
    NSMutableDictionary *dnsDict = [NSMutableDictionary new];
    res_state res = malloc(sizeof(struct __res_state));
    int result = res_ninit(res);
    if (result == 0) {
        for (int i=0;i<res->nscount;i++) {
            NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [dnsDict setValue:s forKey:[NSString stringWithFormat:@"dns%d",i+1]];
        }
    }
    res_nclose(res);
    res_ndestroy(res);
    free(res);
    return dnsDict;
}
#pragma mark ========== 蓝牙 ==========
- (void)bluteeh{
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *strMessage = nil;
    switch (central.state) {
        case CBManagerStatePoweredOn: {
            ZYDebug(@"蓝牙开启且可用");
            //周边外设扫描
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            return;
        }
            break;
        case CBManagerStateUnknown: {
            strMessage = @"手机没有识别到蓝牙，请检查手机。";
        }
            break;
        case CBManagerStateResetting: {
            strMessage = @"手机蓝牙已断开连接，重置中...";
        }
            break;
        case CBManagerStateUnsupported: {
            strMessage = @"手机不支持蓝牙功能，请更换手机。";
        }
            break;
        case CBManagerStatePoweredOff: {
            strMessage = @"手机蓝牙功能关闭，请前往设置打开蓝牙及控制中心打开蓝牙。";
        }
            break;
        case CBManagerStateUnauthorized: {
            strMessage = @"手机蓝牙功能没有权限，请前往设置。";
        }
            break;
        default: { }
            break;
    }
    
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral.name.length == 0) {
        return;
    }
    if(![self.devicesListArray containsObject:peripheral] && peripheral.name>0)
        [self.devicesListArray addObject:peripheral];
    
    NSLog(@"%@", peripheral.identifier);
    NSLog(@"%@", RSSI);
    ZYDebug(@"扫描到一个设备设备：%@",peripheral.name);
    ZYDebug(@"advertisementData: %@",advertisementData);
    // RSSI 是设备信号强度
    // advertisementData 设备广告标识
    // 一般把新扫描到的设备添加到一个数组中，并更新列表
}
#pragma mark ========== WIFI的SSID 与 IP ==========
/**
 * iOS 12 之后WifiSSID 需要配置 'capability' ->'Access WiFi Infomation' 才能获取 还需要配置证书
 * iOS 13 之后需要定位开启 才能获取到信息
 */
- (NSDictionary *)getWifiAndIPAddress{
    if (@available(iOS 13.0, *)) {
        if ([CLLocationManager locationServicesEnabled] && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways)) {
            return @{@"wifi_ssid": [self getCurrentWifiSSID],@"wifi_ip": [self getIPAddress]};
        }else if ([CLLocationManager authorizationStatus] ==kCLAuthorizationStatusDenied) {
            ZYDebug(@"用户拒绝授权或未开启定位服务");
        }
        return nil;
    }else{
        return @{@"wifi_ssid": [self getCurrentWifiSSID],@"wifi_ip": [self getIPAddress]};
    }
}
// 获取设备当前连接的WIFI的SSID  需要配置 Access WiFi Infomation
- (NSString *)getCurrentWifiSSID{
    NSString * wifiName = @"Not Found";
    CFArrayRef wifiInterfaces = CNCopySupportedInterfaces();
    if (!wifiInterfaces) {
        wifiName = @"N/A";
    }
    NSArray *interfaces = (__bridge NSArray *)wifiInterfaces;
    for (NSString *interfaceName in interfaces) {
        CFDictionaryRef dictRef = CNCopyCurrentNetworkInfo((__bridge CFStringRef)(interfaceName));
        if (dictRef) {
            NSDictionary *networkInfo = (__bridge NSDictionary *)dictRef;
            wifiName = [networkInfo objectForKey:(__bridge NSString *)kCNNetworkInfoKeySSID];
            CFRelease(dictRef);
        }
    }
    return wifiName;
}
// - 获取当前Wi-Fi的IP
- (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}
-(void)dealloc{
    [self stopFlushTimer];
    self.netFlow = nil;
}
@end
