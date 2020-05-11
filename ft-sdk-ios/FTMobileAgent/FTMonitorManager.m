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
#import "ZYLog.h"
#import "FTUploadTool.h"
#import <CoreMotion/CoreMotion.h>
#import "FTMoniorUtils.h"
#import <AVFoundation/AVFoundation.h>
#define WeakSelf __weak typeof(self) weakSelf = self;
typedef void (^FTPedometerHandler)(NSNumber *pedometerSteps,
NSError *error);
@interface FTTaskMetrics : NSObject
@property (nonatomic, assign) NSTimeInterval tcpTime;
@property (nonatomic, assign) NSTimeInterval dnsTime;
@property (nonatomic, assign) NSTimeInterval responseTime;
@end
@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate,FTHTTPProtocolDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *devicesListArray;
@property (nonatomic, assign) FTMonitorInfoType monitorType;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, assign) NSInteger errorNet;
@property (nonatomic, assign) NSInteger successNet;
@property (nonatomic, strong) FTTaskMetrics *metrics;
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSNumber *steps;
@property (nonatomic, assign) NSInteger flushInterval;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) float lightValue;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) NSTimeInterval lastTime;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) int fps;
@property (nonatomic, strong) NSDictionary *blDict;
@property (nonatomic, copy) NSString *isBlueOn;
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
@implementation FTMonitorManager
static FTMonitorManager *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.devicesListArray = [NSMutableArray new];
        self.metrics = [FTTaskMetrics new];
        _flushInterval = 10;
        [self startNetMonitor];
    }
    return self;
}
-(void)setMonitorType:(FTMonitorInfoType)type{
    _monitorType = type;
    _monitorTagDict = [self getMonitorTagDicts];
    if (type == 0) {
        [self stopFlush];
    }
    if (!(_monitorType & FTMonitorInfoTypeAll) && !(_monitorType &FTMonitorInfoTypeNetwork)) {
           [self.netFlow stopMonitor];
       }else{
           [self startFlushTimer];
       }
       if(_monitorType & FTMonitorInfoTypeLocation ||_monitorType & FTMonitorInfoTypeAll){
           if ([[FTLocationManager sharedInstance].location.country isEqualToString:@"N/A"]) {
               [[FTLocationManager sharedInstance] startUpdatingLocation];
           }
       }
       if (_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll) {
           if ([CMPedometer isStepCountingAvailable] && !_pedometer) {
               self.pedometer = [[CMPedometer alloc] init];
               [self startPedometerUpdatesTodayWithHandler:nil];
           }
           [self lightSensitive];
       }else if(_monitorType & FTMonitorInfoTypeSensorStep){
           if ([CMPedometer isStepCountingAvailable] && !_pedometer) {
               self.pedometer = [[CMPedometer alloc] init];
               [self startPedometerUpdatesTodayWithHandler:nil];
           }
           [self startMotionUpdate];
       }else if (_monitorType & FTMonitorInfoTypeSensorLight){
           [self lightSensitive];
       }else{
           [self stopMotionUpdates];
           [self.session stopRunning];
       }
       [self startMotionUpdate];
    if (_monitorType & FTMonitorInfoTypeAll || _monitorType & FTMonitorInfoTypeFPS) {
        if (!_link) {
            _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
            [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    }
    if (_monitorType & FTMonitorInfoTypeAll || _monitorType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
}
-(void)setFlushInterval:(NSInteger)interval{
    _flushInterval = interval;
    if(_timer){
        [self stopFlush];
        [self startFlush];
    }
}
-(void)startFlush{
    if ((self.timer && [self.timer isValid])) {
        return;
    }
    ZYDebug(@"starting monitor flush timer.");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.flushInterval > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }
    });
}
-(void)stopFlush{
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = nil;
}
-(void)flush{
    NSDictionary *addDict = [self getMonitorTagFiledDict];
    FTRecordModel *model = [FTRecordModel new];
    NSString *measurement = @"mobile_monitor";

    NSMutableDictionary *opdata = @{
        @"measurement":measurement}.mutableCopy;
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
#pragma mark ========== FPS ==========
- (void)tick:(CADisplayLink *)link {
    if (_lastTime == 0) {
        _lastTime = link.timestamp;
        return;
    }
    _count++;
    NSTimeInterval delta = link.timestamp - _lastTime;
    if (delta < 1) return;
    _lastTime = link.timestamp;
    float fps = _count / delta;
    _count = 0;
    _fps = (int)round(fps);
}

#pragma mark ========== 传感器数据获取 ==========
- (void)lightSensitive{
    if (_session|| [_session isRunning]) {
        return;
    }
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // 2.创建输入流
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc]initWithDevice:device error:nil];
    
    // 3.创建设备输出流
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    if (input == nil || output == nil) {
        ZYLog(@"模拟器无法获取环境光感参数");
        return;
    }
    dispatch_queue_t  bufferQueue = dispatch_queue_create([@"ft_buffer_light" UTF8String], DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:bufferQueue];
    
    // AVCaptureSession属性
    self.session = [[AVCaptureSession alloc]init];
    // 设置为高质量采集率
    [self.session setSessionPreset:AVCaptureSessionPresetLow];
    // 添加会话输入和输出
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
    }
    
    // 9.启动会话
    [self.session startRunning];
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

  CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
  NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
  CFRelease(metadataDict);
  NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
  float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];

    self.lightValue = brightnessValue;
}

-(CMMotionManager *)motionManager{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc]init];
    }
    return _motionManager;
}
- (void)startMotionUpdate{
    if (_monitorType & FTMonitorInfoTypeSensorMagnetic ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll  ) {
        if ([self.motionManager isMagnetometerAvailable] && ![self.motionManager isMagnetometerActive]) {
            [self.motionManager startMagnetometerUpdates];
        }
    }
    if (_monitorType & FTMonitorInfoTypeSensorAcceleration ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll  ) {
        if ([self.motionManager isAccelerometerAvailable] && ![self.motionManager isAccelerometerActive]) {
         [self.motionManager startAccelerometerUpdates];
    }
    }
     if (_monitorType & FTMonitorInfoTypeSensorRotation ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll  )
       if([self.motionManager isGyroAvailable] && ![self.motionManager isGyroActive]){
        [self.motionManager startGyroUpdates];
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
      self.steps = pedometerData.numberOfSteps;
      handler? handler(pedometerData.numberOfSteps, error):nil;
                        }];
}
- (NSDictionary *)getMotionDatas{
    NSMutableDictionary *field = [NSMutableDictionary new];
    if([self.motionManager isGyroAvailable] && (_monitorType & FTMonitorInfoTypeSensorRotation ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll)){
        [field addEntriesFromDictionary:@{@"rotation_x":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.x],
                                          @"rotation_y":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.y],
                                          @"rotation_z":[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.z]}];
    }
    if ([self.motionManager isAccelerometerAvailable]&&(_monitorType & FTMonitorInfoTypeSensorAcceleration ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll) ) {
        [field addEntriesFromDictionary:@{@"acceleration_x":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.x],
                                          @"acceleration_y":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.y],
                                          @"acceleration_z":[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.z]}];
    }
    if ([self.motionManager isMagnetometerAvailable]&&(_monitorType & FTMonitorInfoTypeSensorMagnetic ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll)) {
        [field addEntriesFromDictionary:@{@"magnetic_x":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.x],
                                          @"magnetic_y":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.y],
                                          @"magnetic_z":[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.z]}];
    }
    if(_pedometer && (_monitorType & FTMonitorInfoTypeSensorStep ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll)){
    [self startPedometerUpdatesTodayWithHandler:nil];
    [field setValue:self.steps forKey:@"steps"];
    }
    if (_monitorType & FTMonitorInfoTypeSensorLight ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll){
        [field setValue:[NSNumber numberWithFloat:self.lightValue] forKey:@"light"];
    }

    return field;
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
-(NSDictionary *)getMonitorTagDicts{
        NSMutableDictionary *tag = [NSMutableDictionary new];
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        if (self.monitorType &FTMonitorInfoTypeBattery || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:@"battery_total"];
        }
        if (self.monitorType & FTMonitorInfoTypeMemory || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTMoniorUtils ft_getTotalMemorySize] forKey:@"memory_total"];
        }
        if (self.monitorType &FTMonitorInfoTypeCpu || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:@"cpu_no"];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:@"cpu_hz"];
        }
        if(self.monitorType & FTMonitorInfoTypeGpu || self.monitorType & FTMonitorInfoTypeAll){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:@"gpu_model"];
        }
        if (self.monitorType & FTMonitorInfoTypeCamera || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTMoniorUtils ft_getFrontCameraPixel] forKey:@"camera_front_px"];
            [tag setObject:[FTMoniorUtils ft_getBackCameraPixel] forKey:@"camera_back_px"];
        }
        if (self.monitorType & FTMonitorInfoTypeSystem || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setValue:[FTMoniorUtils userDeviceName] forKey:@"device_name"];
        }
    return tag;
}
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];
    if (self.monitorType & FTMonitorInfoTypeSystem || self.monitorType & FTMonitorInfoTypeAll) {
        [field setValue:[FTMoniorUtils getLaunchSystemTime] forKey:@"device_open_time"];
    }
    if (self.monitorType &FTMonitorInfoTypeCpu || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithLong:[FTMoniorUtils ft_cpuUsage]] forKey:@"cpu_use"];
    }
    if (self.monitorType & FTMonitorInfoTypeMemory || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTMoniorUtils ft_usedMemory]] forKey:@"memory_use"];
    }
    if (self.monitorType & FTMonitorInfoTypeNetwork || self.monitorType & FTMonitorInfoTypeAll) {
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
        NSString *roam = [FTMoniorUtils getRoamingStates] == NO?@"false":@"true";
        [tag setObject:roam forKey:@"roam"];
        [tag setObject:network_type forKey:@"network_type"];
        [field setObject:network_strength forKey:@"network_strength"];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.iflow] forKey:@"network_in_rate"];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.oflow] forKey:@"network_out_rate"];
        [field addEntriesFromDictionary:[FTMoniorUtils getWifiAccessAndIPAddress]];
        [field setObject:[NSNumber numberWithDouble:self.metrics.dnsTime] forKey:@"network_dns_time"];
        [field setObject:[NSNumber numberWithDouble:self.metrics.tcpTime] forKey:@"network_tcp_time"];
        [field setObject:[NSNumber numberWithDouble:self.metrics.responseTime] forKey:@"network_response_time"];
        [field addEntriesFromDictionary:[FTMoniorUtils getDNSInfo]];
        if (self.successNet+self.errorNet != 0) {
            [field setObject:[NSNumber numberWithDouble:self.errorNet/((self.successNet+self.errorNet)*1.0)] forKey:@"network_error_rate"];
        }else{
            [field setObject:@0 forKey:@"network_error_rate"];
        }
        if ([FTNetworkInfo getProxyHost]) {
            [tag setObject:[FTNetworkInfo getProxyHost] forKey:@"network_proxy"];
        }else{
            [tag setObject:@"N/A" forKey:@"network_proxy"];
        }
    }
    if (self.monitorType & FTMonitorInfoTypeBattery || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTMoniorUtils ft_getBatteryUse]] forKey:@"battery_use"];
        [tag setObject:[FTMoniorUtils ft_batteryStatus] forKey:@"battery_status"];
    }
    if (self.monitorType & FTMonitorInfoTypeGpu || self.monitorType & FTMonitorInfoTypeAll){
        double usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [field setObject:[NSNumber numberWithDouble:usage] forKey:@"gpu_rate"];
    }
    if (self.monitorType & FTMonitorInfoTypeLocation || self.monitorType & FTMonitorInfoTypeAll) {
        [tag setValue:[FTLocationManager sharedInstance].location.province forKey:@"province"];
        [tag setValue:[FTLocationManager sharedInstance].location.city forKey:@"city"];
        [tag setValue:[FTLocationManager sharedInstance].location.country forKey:@"country"];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.latitude] forKey:@"latitude"];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.longitude] forKey:@"longitude"];
        NSString *gpsOpen = [[FTLocationManager sharedInstance] gpsServicesEnabled]==0?@"false":@"true";
        [tag setValue:gpsOpen forKey:@"gps_open"];
    }
    if (self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll || self.monitorType & FTMonitorInfoTypeSensorBrightness) {
        [field setValue:[NSNumber numberWithFloat:[FTMoniorUtils screenBrightness]] forKey:@"screen_brightness"];
    }
    if (self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll || self.monitorType & FTMonitorInfoTypeSensorProximity) {
//       NSString *proximity =[FTMoniorUtils getProximityState] == NO?@"false":@"true";
        [field setValue:[NSNumber numberWithBool:[FTMoniorUtils getProximityState]]  forKey:@"proximity"];
    }
    if (self.monitorType & FTMonitorInfoTypeFPS || self.monitorType &FTMonitorInfoTypeAll) {
        [field setValue:[NSNumber numberWithInt:_fps] forKey:@"fps"];
    }
    if (self.monitorType & FTMonitorInfoTypeBluetooth || self.monitorType & FTMonitorInfoTypeAll) {
        [field addEntriesFromDictionary:_blDict];
        [tag setValue:self.isBlueOn forKey:@"bt_open"];
        
    }
    if (self.monitorType & FTMonitorInfoTypeSensorTorch ||self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll){
        NSString *torch =[FTMoniorUtils getTorchLevel] == 0?@"false":@"true";
        [tag setValue:torch forKey:@"torch"];
    }
    [field addEntriesFromDictionary:[self getMotionDatas]];
    
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
    if (self.monitorType & FTMonitorInfoTypeNetwork || self.monitorType & FTMonitorInfoTypeAll) {
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
//#pragma mark ========== 蓝牙 ==========
-(void)setConnectBluetoothCBUUID:(NSArray<CBUUID *> *)serviceUUIDs{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [serviceUUIDs enumerateObjectsUsingBlock:^(CBUUID *obj, NSUInteger idx, BOOL *stop) {
        [dict setValue:[obj UUIDString] forKey:[NSString stringWithFormat:@"bt_device_%lu",(unsigned long)idx]];
    }];
    _blDict = dict;
}
- (void)bluteeh{
    if (!_centralManager) {
        NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
    }
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (@available(iOS 10.0, *)) {
        self.isBlueOn = (central.state ==CBManagerStatePoweredOn)? @"true":@"false";
    } 
}

- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
    [self stopFlushTimer];
    [self stopMotionUpdates];
    [_session stopRunning];
    self.netFlow = nil;
}
@end
