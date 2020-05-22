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
#import "FTLog.h"
#import "FTUploadTool.h"
#import <CoreMotion/CoreMotion.h>
#import "FTMonitorUtils.h"
#import <AVFoundation/AVFoundation.h>
#import "FTConstants.h"
#import "FTURLProtocol.h"
#import "FTMobileAgent+Private.h"
#define WeakSelf __weak typeof(self) weakSelf = self;
typedef void (^FTPedometerHandler)(NSNumber *pedometerSteps,
NSError *error);
@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate, AVCaptureVideoDataOutputSampleBufferDelegate,FTHTTPProtocolDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *devicesListArray;
@property (nonatomic, assign) FTMonitorInfoType monitorType;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSNumber *steps;
@property (nonatomic, assign) NSInteger flushInterval;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) float lightValue;
@property (nonatomic, strong) NSDictionary *blDict;
@property (nonatomic, copy) NSString *isBlueOn;
@end

@implementation FTMonitorManager{
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _count;
    float _fps;
    NSDictionary *_lastNetTaskMetrics;
    NSUInteger _errorNet;
    NSUInteger _successNet;
}
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
        _flushInterval = 10;
        _lastNetTaskMetrics = nil;
        _errorNet = 0;
        _successNet = 0;
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
        [FTURLProtocol stopMonitor];
    }else{
        [FTURLProtocol startMonitor];
        [FTURLProtocol setDelegate:self];
        [self startFlushTimer];
    }
    if(_monitorType & FTMonitorInfoTypeLocation ||_monitorType & FTMonitorInfoTypeAll){
        if ([[FTLocationManager sharedInstance].location.country isEqualToString:FT_NULL_VALUE]) {
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
        if (!_displayLink) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
            [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(applicationDidBecomeActiveNotification)
                                                         name: UIApplicationDidBecomeActiveNotification
                                                       object: nil];
            
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(applicationWillResignActiveNotification)
                                                         name: UIApplicationWillResignActiveNotification
                                                       object: nil];
        }
    }else{
        if (_displayLink) {
            [_displayLink setPaused:YES];
            _displayLink = nil;
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
    if (self.monitorType == 0) {
        return;
    }
    NSDictionary *addDict = [self getMonitorTagFiledDict];
    FTRecordModel *model = [FTRecordModel new];

    NSMutableDictionary *opdata = @{
        FT_AGENT_MEASUREMENT:@"mobile_monitor"}.mutableCopy;
    if ([addDict objectForKey:FT_AGENT_TAGS]) {
        [opdata setValue:[addDict objectForKey:FT_AGENT_TAGS] forKey:FT_AGENT_TAGS];
    }
    if ([addDict objectForKey:FT_AGENT_FIELD]) {
        [opdata setValue:[addDict objectForKey:FT_AGENT_FIELD] forKey:FT_AGENT_FIELD];
    }
    NSDictionary *data =@{
        FT_AGENT_OP:@"monitor",
        FT_AGENT_OPDATA:opdata,
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
    _fps = _count / delta;
    _count = 0;
}
- (void)applicationDidBecomeActiveNotification {
    [_displayLink setPaused:NO];
    [_netFlow startMonitor];
}
- (void)applicationWillResignActiveNotification {
    [_displayLink setPaused:YES];
    [_netFlow stopMonitor];
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
        [field addEntriesFromDictionary:@{FT_MONITOR_ROTATION_X:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.x],
                                          FT_MONITOR_ROTATION_Y:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.y],
                                          FT_MONITOR_ROTATION_Z:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.z]}];
    }
    if ([self.motionManager isAccelerometerAvailable]&&(_monitorType & FTMonitorInfoTypeSensorAcceleration ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll) ) {
        [field addEntriesFromDictionary:@{FT_MONITOR_ACCELERATION_X:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.x],
                                          FT_MONITOR_ACCELERATION_Y:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.y],
                                          FT_MONITOR_ACCELERATION_Z:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.z]}];
    }
    if ([self.motionManager isMagnetometerAvailable]&&(_monitorType & FTMonitorInfoTypeSensorMagnetic ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll)) {
        [field addEntriesFromDictionary:@{FT_MONITOR_MAGNETIC_X:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.x],
                                          FT_MONITOR_MAGNETIC_Y:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.y],
                                          FT_MONITOR_MAGNETIC_Z:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.z]}];
    }
    if(_pedometer && (_monitorType & FTMonitorInfoTypeSensorStep ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll)){
        [self startPedometerUpdatesTodayWithHandler:nil];
        [field setValue:self.steps forKey:FT_MONITOR_STEPS];
    }
    if (_monitorType & FTMonitorInfoTypeSensorLight ||_monitorType & FTMonitorInfoTypeSensor || _monitorType & FTMonitorInfoTypeAll){
        [field setValue:[NSNumber numberWithFloat:self.lightValue] forKey:FT_MONITOR_LIGHT];
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
#pragma mark ========== tag\field 数据拼接 ==========
-(NSDictionary *)getMonitorTagDicts{
        NSMutableDictionary *tag = [NSMutableDictionary new];
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        if (self.monitorType &FTMonitorInfoTypeBattery || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:FT_MONITOR_BATTERY_TOTAL];
        }
        if (self.monitorType & FTMonitorInfoTypeMemory || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTMonitorUtils ft_getTotalMemorySize] forKey:FT_MONITOR_MEMORY_TOTAL];
        }
        if (self.monitorType &FTMonitorInfoTypeCpu || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:FT_MONITOR_CPU_NO];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:FT_MONITOR_CPU_HZ];
        }
        if(self.monitorType & FTMonitorInfoTypeGpu || self.monitorType & FTMonitorInfoTypeAll){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:FT_MONITOR_GPU_MODEL];
        }
        if (self.monitorType & FTMonitorInfoTypeCamera || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTMonitorUtils ft_getFrontCameraPixel] forKey:FT_MONITOR_CAMERA_FRONT_PX];
            [tag setObject:[FTMonitorUtils ft_getBackCameraPixel] forKey:FT_MONITOR_CAMERA_BACK_PX];
        }
        if (self.monitorType & FTMonitorInfoTypeSystem || self.monitorType & FTMonitorInfoTypeAll) {
            [tag setValue:[FTMonitorUtils userDeviceName] forKey:FT_MONITOR_DEVICE_NAME];
        }
    return tag;
}
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];
    if (self.monitorType & FTMonitorInfoTypeSystem || self.monitorType & FTMonitorInfoTypeAll) {
        [field setValue:[FTMonitorUtils getLaunchSystemTime] forKey:FT_MONITOR_DEVICE_OPEN_TIME];
    }
    if (self.monitorType &FTMonitorInfoTypeCpu || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithLong:[FTMonitorUtils ft_cpuUsage]] forKey:FT_MONITOR_CPU_USE];
    }
    if (self.monitorType & FTMonitorInfoTypeMemory || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_usedMemory]] forKey:FT_MONITOR_MEMORY_USE];
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
        NSString *roam = [FTMonitorUtils getRoamingStates] == NO?@"false":@"true";
        [tag setObject:roam forKey:FT_MONITOR_ROAM];
        [tag setObject:network_type forKey:FT_MONITOR_NETWORK_TYPE];
        if([network_type isEqualToString:@"WIFI"]){
            [field addEntriesFromDictionary:[FTMonitorUtils getWifiAccessAndIPAddress]];
        }else{
            [field addEntriesFromDictionary:@{FT_MONITOR_WITF_SSID:FT_NULL_VALUE,FT_MONITOR_WITF_IP:FT_NULL_VALUE}];
        }
        [field setObject:network_strength forKey:FT_MONITOR_NETWORK_STRENGTH];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.iflow] forKey:FT_MONITOR_NETWORK_IN_RATE];
        [field setObject:[NSNumber numberWithLongLong:self.netFlow.oflow] forKey:FT_MONITOR_NETWORK_OUT_RATE];
        [field addEntriesFromDictionary:_lastNetTaskMetrics];
        [field addEntriesFromDictionary:[FTMonitorUtils getDNSInfo]];
        NSNumber *errorRate = @0;
        if (_successNet+_errorNet != 0) {
            errorRate =[NSNumber numberWithDouble:_errorNet/((_successNet+_errorNet)*1.0)];
        }
        [field setObject:errorRate forKey:FT_MONITOR_NETWORK_ERROR_RATE];
        [tag setObject:[FTNetworkInfo getProxyHost] forKey:FT_MONITOR_NETWORK_PROXY];
    }
    if (self.monitorType & FTMonitorInfoTypeBattery || self.monitorType & FTMonitorInfoTypeAll) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_getBatteryUse]] forKey:FT_MONITOR_BATTERY_USE];
        [tag setObject:[FTMonitorUtils ft_batteryStatus] forKey:FT_MONITOR_BATTERY_STATUS];
    }
    if (self.monitorType & FTMonitorInfoTypeGpu || self.monitorType & FTMonitorInfoTypeAll){
        double usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [field setObject:[NSNumber numberWithDouble:usage] forKey:FT_MONITOR_GPU_RATE];
    }
    if (self.monitorType & FTMonitorInfoTypeLocation || self.monitorType & FTMonitorInfoTypeAll) {
        [tag setValue:[FTLocationManager sharedInstance].location.province forKey:FT_MONITOR_PROVINCE];
        [tag setValue:[FTLocationManager sharedInstance].location.city forKey:FT_MONITOR_CITY];
        [tag setValue:[FTLocationManager sharedInstance].location.country forKey:FT_MONITOR_COUNTRY];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.latitude] forKey:FT_MONITOR_LATITUDE];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.longitude] forKey:FT_MONITOR_LONGITUDE];
        NSString *gpsOpen = [[FTLocationManager sharedInstance] gpsServicesEnabled]==0?@"false":@"true";
        [tag setValue:gpsOpen forKey:FT_MONITOR_GPS_OPEN];
    }
    if (self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll || self.monitorType & FTMonitorInfoTypeSensorBrightness) {
        [field setValue:[NSNumber numberWithFloat:[FTMonitorUtils screenBrightness]] forKey:FT_MONITOR_SCREEN_BRIGHTNESS];
    }
    if (self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll || self.monitorType & FTMonitorInfoTypeSensorProximity) {
        [field setValue:[NSNumber numberWithBool:[FTMonitorUtils getProximityState]]  forKey:FT_MONITOR_PROXIMITY];
    }
    if (self.monitorType & FTMonitorInfoTypeFPS || self.monitorType &FTMonitorInfoTypeAll) {
        [field setValue:[NSNumber numberWithInt:_fps] forKey:FT_MONITOR_FPS];
    }
    if (self.monitorType & FTMonitorInfoTypeBluetooth || self.monitorType & FTMonitorInfoTypeAll) {
        [field addEntriesFromDictionary:_blDict];
        [tag setValue:self.isBlueOn forKey:FT_MONITOR_BT_OPEN];
        
    }
    if (self.monitorType & FTMonitorInfoTypeSensorTorch ||self.monitorType & FTMonitorInfoTypeSensor || self.monitorType & FTMonitorInfoTypeAll){
        NSString *torch =[FTMonitorUtils getTorchLevel] == 0?@"false":@"true";
        [tag setValue:torch forKey:FT_MONITOR_TORCH];
    }
    [field addEntriesFromDictionary:[self getMotionDatas]];
    
    return @{FT_AGENT_FIELD:field,FT_AGENT_TAGS:tag};
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
#pragma mark ========== 网络请求相关时间/错误率 ==========
- (void)ftHTTPProtocol:(FTURLProtocol *)protocol didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    if (@available(iOS 10.0, *)) {
        NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics firstObject];
        NSTimeInterval dnsTime = [taskMes.domainLookupEndDate timeIntervalSinceDate:taskMes.domainLookupStartDate]*1000;
        NSTimeInterval tcpTime = [taskMes.connectEndDate timeIntervalSinceDate:taskMes.connectStartDate]*1000;
        NSTimeInterval responseTime = [taskMes.responseEndDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
        if([taskMes.request.URL.absoluteString isEqualToString:[FTMobileAgent sharedInstance].config.metricsUrl]){
            @synchronized(_lastNetTaskMetrics) {
                _lastNetTaskMetrics = @{FT_MONITOR_FT_NETWORK_DNS_TIME:[NSNumber numberWithDouble:dnsTime],
                                        FT_MONITOR_FT_NETWORK_TCP_TIME:[NSNumber numberWithDouble:tcpTime],
                                        FT_MONITOR_FT_NETWORK_RESPONSE_TIME:[NSNumber numberWithDouble:responseTime]
                };
            }
        }else{
            @synchronized(_lastNetTaskMetrics) {
                _lastNetTaskMetrics = @{FT_MONITOR_NETWORK_DNS_TIME:[NSNumber numberWithDouble:dnsTime],
                                        FT_MONITOR_NETWORK_TCP_TIME:[NSNumber numberWithDouble:tcpTime],
                                        FT_MONITOR_NETWORK_RESPONSE_TIME:[NSNumber numberWithDouble:responseTime]
                };
            }
        }
    }
}
- (void)ftHTTPProtocol:(FTURLProtocol *)protocol didCompleteWithError:(NSError *)error{
    if (error) {
        _errorNet++;
    }else{
        _successNet++;
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
