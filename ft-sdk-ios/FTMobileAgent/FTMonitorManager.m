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
#import <SystemConfiguration/CaptiveNetwork.h>
#import "FTLocationManager.h"
#import "FTBaseInfoHander.h"
#import "FTMobileConfig.h"
#import "FTNetworkInfo.h"
#import "FTNetMonitorFlow.h"
#import "FTGPUUsage.h"
#import "FTRecordModel.h"
#import "FTMobileAgent.h"
#import<CoreMotion/CoreMotion.h> //陀螺仪
#import "FTURLProtocol.h"
#import "FTMonitorManager+MoniorUtils.h"
#import "ZYLog.h"
#import "FTUploadTool.h"
#import "FTCMMotionManager.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate,FTHTTPProtocolDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *devicesListArray;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, assign) CMAcceleration acceleration;
@property (nonatomic, assign) NSInteger errorNet;
@property (nonatomic, assign) NSInteger successNet;
@property (nonatomic, strong) FTTaskMetrics *metrics;
@end
@implementation FTTaskMetrics
-(instancetype)init{
    if(self = [super init]){
        self.tcpTime = 0;
        self.dnsTime = 0;
        self.responseTime = 0;
    }
    return self;
}
@end
@implementation FTMonitorManager{
    //定时器
    NSTimer *timer;
    //添加成功的service数量
    int serviceNum;
    UILabel *info;
   
}
-(instancetype)initWithConfig:(FTMobileConfig *)config{
    self = [super init];
    if (self) {
        self.devicesListArray = [NSMutableArray new];
        self.config = config;
        self.metrics = [FTTaskMetrics new];
        [self bluteeh];
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
    if (_config.monitorInfoType & FTMonitorInfoTypeSensor || _config.monitorInfoType & FTMonitorInfoTypeAll) {
        [[FTCMMotionManager shared] startMotionUpdate];
    }else{
        [[FTCMMotionManager shared] stopMotionUpdates];
    }
}
-(FTNetMonitorFlow *)netFlow{
    if (!_netFlow) {
        _netFlow = [FTNetMonitorFlow new];
    }
    return _netFlow;
}
-(void)flush{
    NSDictionary *addDict = [self getMonitorTagFiledDict];
    FTRecordModel *model = [FTRecordModel new];
    NSMutableDictionary *opdata = @{
        @"measurement":@"ios_device_monitor"}.mutableCopy;
    if ([addDict objectForKey:@"tag"]) {
        [opdata setValue:[addDict objectForKey:@"tag"] forKey:@"tags"];
    }
    if ([addDict objectForKey:@"field"]) {
        [opdata setValue:[addDict objectForKey:@"field"] forKey:@"field"];
    }
    NSDictionary *data =@{
        @"op":@"monitor",
        @"opdata":opdata,
    };
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    model.tm = [FTBaseInfoHander ft_getCurrentTimestamp];
    void (^UploadResultBlock)(NSInteger,id) = ^(NSInteger statusCode,id responseObject){
        ZYDebug(@"statusCode == %d\nresponseObject == %@",statusCode,responseObject);
    };
    [[FTMobileAgent sharedInstance] performSelector:@selector(trackUpload:callBack:) withObject:@[model] withObject:UploadResultBlock];
}
#pragma mark ========== 网络请求相关时间 ==========
- (void)startNetMonitor{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealTaskMetrics:) name:FTTaskMetricsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealTaskStates:) name:FTTaskCompleteStatesNotification object:nil];
}
-(void)dealTaskMetrics:(NSNotification *)notification{
    NSDictionary * infoDic = [notification object];
    if ([[infoDic allKeys]containsObject:@"metrics"]) {
        if (@available(iOS 10.0, *)) {
            NSURLSessionTaskMetrics *metrics = infoDic[@"metrics"];
            NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
            self.metrics.dnsTime = [taskMes.connectEndDate timeIntervalSinceDate:taskMes.domainLookupStartDate]*1000;
            self.metrics.tcpTime = [taskMes.secureConnectionStartDate timeIntervalSinceDate:taskMes.connectStartDate]*1000;
            self.metrics.responseTime = [taskMes.responseEndDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
        }
    }
}
-(void)dealTaskStates:(NSNotification *)notification{
    NSDictionary * infoDic = [notification object];
    if ([[infoDic allKeys]containsObject:@"success"]) {
        if (infoDic[@"success"]) {
            self.successNet++;
        }else{
            self.errorNet++;
        }
    }
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
        if (self.config.monitorInfoType & FTMonitorInfoTypeSystem || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setValue:[FTMonitorManager userDeviceName] forKey:@"device_name"];
            [tag setValue:[FTMonitorManager getLaunchSystemTime] forKey:@"device_open_time"];
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
        [network_type isEqualToString:@"WIFI"]?[field addEntriesFromDictionary:[FTMonitorManager getWifiAndIPAddress]]:nil;
        [field setObject:[NSNumber numberWithDouble:self.metrics.dnsTime] forKey:@"network_dns_time"];
        [field setObject:[NSNumber numberWithDouble:self.metrics.tcpTime] forKey:@"network_tcp_time"];
        [field setObject:[NSNumber numberWithDouble:self.metrics.responseTime] forKey:@"network_response_time"];
        if (self.successNet+self.errorNet != 0) {
            [field setObject:[NSNumber numberWithDouble:self.errorNet/((self.successNet+self.errorNet)*1.0)] forKey:@"network_error_rate"];
        }
        if ([FTNetworkInfo getProxyHost]) {
            [tag setObject:[FTNetworkInfo getProxyHost] forKey:@"network_proxy"];
        }else{
            [tag setObject:@"N/A" forKey:@"network_proxy"];
        }
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTBaseInfoHander ft_getBatteryUse]] forKey:@"battery_use"];
        [tag setObject:[NSNumber numberWithBool:[FTBaseInfoHander ft_batteryIsCharing]] forKey:@"battery_charing"];
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
        [tag setValue:[NSNumber numberWithBool:[[FTLocationManager sharedInstance] gpsServicesEnabled]] forKey:@"gps_open"];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeSensor || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [field setValue:[NSNumber numberWithFloat:[FTMonitorManager screenBrightness]] forKey:@"screen_brightness"];
        [field setValue:[NSNumber numberWithBool:[FTMonitorManager getProximityState]] forKey:@"proximity"];
        [field setValue:[NSNumber numberWithFloat:[FTMonitorManager getTorchLevel]] forKey:@"torch"];
        [field addEntriesFromDictionary:[[FTCMMotionManager shared] getMotionDatas]];
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
-(void)dealloc{
    [self stopFlushTimer];
    self.netFlow = nil;
}
@end
