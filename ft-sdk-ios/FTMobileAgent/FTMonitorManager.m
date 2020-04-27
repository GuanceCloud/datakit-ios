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
#import "FTURLProtocol.h"
#import "FTMonitorManager+MoniorUtils.h"
#import "ZYLog.h"
#import "FTUploadTool.h"
#import <CoreMotion/CoreMotion.h>
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate,FTHTTPProtocolDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *devicesListArray;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, assign) NSInteger errorNet;
@property (nonatomic, assign) NSInteger successNet;
@property (nonatomic, strong) FTTaskMetrics *metrics;
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMMotionManager *motionManager;
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
        [self startNetMonitor];
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
        if ([CMPedometer isStepCountingAvailable] && !_pedometer) {
            self.pedometer = [[CMPedometer alloc] init];
        }
        [self startMotionUpdate];
    }else{
        [self stopMotionUpdates];
    }
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
#pragma mark ========== 传感器数据获取 ==========
-(CMMotionManager *)motionManager{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc]init];
    }
    return _motionManager;
}
- (void)startMotionUpdate{
    if([self.motionManager isGyroAvailable] && ![self.motionManager isGyroActive]){
        [self.motionManager startGyroUpdates];
    }
    if ([self.motionManager isAccelerometerAvailable] && ![self.motionManager isAccelerometerActive]) {
        [self.motionManager startAccelerometerUpdates];
    }
    if ([self.motionManager isMagnetometerAvailable] && ![self.motionManager isMagnetometerActive]) {
        [self.motionManager startMagnetometerUpdates];
    }
}
/**
 *  查询某时间段的运动数据
 *
 *  @param start   开始时间
 *  @param end     结束时间
 *  @param handler 查询结果
 */
- (void)queryPedometerDataFromDate:(NSDate *)start
                            toDate:(NSDate *)end
                       withHandler:(FTPedometerHandler)handler {

  [_pedometer
      queryPedometerDataFromDate:start
                          toDate:end
                     withHandler:^(CMPedometerData *_Nullable pedometerData,
                                   NSError *_Nullable error) {
                       dispatch_async(dispatch_get_main_queue(), ^{
                         handler(pedometerData.numberOfSteps, error);
                       });
                     }];

}
/**
 *  监听今天（从零点开始）的行走数据
 *
 *  @param handler 查询结果、变化就更新
 */
- (void)startPedometerUpdatesTodayWithHandler:(FTPedometerHandler)handler{
  NSDate *toDate = [NSDate date];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd"];
  NSDate *fromDate =
      [dateFormatter dateFromString:[dateFormatter stringFromDate:toDate]];
  [_pedometer
      startPedometerUpdatesFromDate:fromDate
                        withHandler:^(CMPedometerData *_Nullable pedometerData,
                                      NSError *_Nullable error) {
                            handler(pedometerData.numberOfSteps, error);
                        }];
}
- (NSDictionary *)getMotionDatas{
    NSMutableDictionary *field = [NSMutableDictionary new];
    if([self.motionManager isGyroAvailable]){
        [field addEntriesFromDictionary:@{@"rotation_x":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.x],
                                          @"rotation_y":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.y],
                                          @"rotation_z":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.z]}];
    }
    if ([self.motionManager isAccelerometerAvailable] ) {
        [field addEntriesFromDictionary:@{@"acceleration_x":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.x],
                                          @"acceleration_y":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.y],
                                          @"acceleration_z":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.z]}];
    }
    if ([self.motionManager isMagnetometerAvailable]) {
        [field addEntriesFromDictionary:@{@"magnetic_x":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.x],
                                          @"magnetic_y":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.y],
                                          @"magnetic_z":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.z]}];
    }
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [self startPedometerUpdatesTodayWithHandler:^(NSNumber * _Nonnull steps, NSError * _Nonnull error) {
        [field addEntriesFromDictionary:@{@"steps":steps}];
          dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return field;
}
-(BOOL)getProximityState{
    if ([UIDevice currentDevice].proximityMonitoringEnabled == NO){
        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
    }
    return [UIDevice currentDevice].proximityState;
}
/**
 *  停止监听运动数据
 */
- (void)stopMotionUpdates {
    [_pedometer stopPedometerUpdates];
    if([_motionManager isGyroActive]){
        [_motionManager stopGyroUpdates];
    }
    if ([_motionManager isAccelerometerActive]) {
        [_motionManager stopAccelerometerUpdates];
    }
    if ([_motionManager isMagnetometerActive]) {
        [_motionManager stopMagnetometerUpdates];
    }
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
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
#pragma mark ========== tag\field 数据拼接 ==========
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
        [field addEntriesFromDictionary:[self getMotionDatas]];
        }
    return @{@"field":field,@"tag":tag};
}
#pragma mark --------- 实时网速 ----------
-(FTNetMonitorFlow *)netFlow{
    if (!_netFlow) {
        _netFlow = [FTNetMonitorFlow new];
    }
    return _netFlow;
}
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
    [self stopMotionUpdates];
    self.netFlow = nil;
}
@end
