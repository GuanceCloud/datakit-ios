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
#import "ZYAspects.h"
#import "NSURLRequest+FTMonitor.h"
#import "NSURLResponse+FTMonitor.h"

#define WeakSelf __weak typeof(self) weakSelf = self;
typedef void (^FTPedometerHandler)(NSNumber *pedometerSteps,
NSError *error);
static NSString * const FTUELSessionLockName = @"com.ft.networking.session.manager.lock";

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate, AVCaptureVideoDataOutputSampleBufferDelegate,FTHTTPProtocolDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *devicesListArray;
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
@property (nonatomic, strong) NSMutableDictionary *mutableTaskDatasKeyedByTaskIdentifier;
@property (readwrite, nonatomic, strong) NSLock *lock;
@end

@implementation FTMonitorManager{
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _count;
    float _fps;
    NSDictionary *_lastNetTaskMetrics;
    NSUInteger _errorNet;
    NSUInteger _successNet;
    BOOL _proximityState;
    BOOL _monitorNetworking;
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
        self.mutableTaskDatasKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
        self.lock = [[NSLock alloc] init];
        self.lock.name = FTUELSessionLockName;
    }
    return self;
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
-(void)setMonitorType:(FTMonitorInfoType)type{
    _monitorType = type;
    _monitorTagDict = [self getMonitorTagDicts];
    if (type == 0) {
        [self stopFlush];
        [self stopMonitor];
        return;
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeNetwork]) {
        [FTURLProtocol startMonitor];
        [FTURLProtocol setDelegate:self];
        [self startFlushTimer];
    }else{
       [_netFlow stopMonitor];
       [FTURLProtocol stopMonitor];
    }
    if([self isMonitorTypeAllow:FTMonitorInfoTypeLocation]){
        if ([[FTLocationManager sharedInstance].location.country isEqualToString:FT_NULL_VALUE]) {
            [[FTLocationManager sharedInstance] startUpdatingLocation];
        }
    }else{
        [[FTLocationManager sharedInstance] stopUpdatingLocation];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorStep]) {
        if ([CMPedometer isStepCountingAvailable] && !_pedometer) {
            self.pedometer = [[CMPedometer alloc] init];
            [self startPedometerUpdatesTodayWithHandler:nil];
        }
    }else{
        _pedometer?[_pedometer stopPedometerUpdates]:nil;
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorLight]) {
        [self lightSensitive];
    }else{
        [_session stopRunning];
    }
    
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorProximity]) {
        [self startMonitorProximity];
    }else{
        [self stopMonitorProximity];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorMagnetic]) {
        if ([self.motionManager isMagnetometerAvailable] && ![self.motionManager isMagnetometerActive]) {
            [self.motionManager startMagnetometerUpdates];
        }
    }else{
        _motionManager.isMagnetometerActive? [_motionManager stopMagnetometerUpdates]:nil;
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorAcceleration]) {
        if ([self.motionManager isAccelerometerAvailable] && ![self.motionManager isAccelerometerActive]) {
            [self.motionManager startAccelerometerUpdates];
        }
    }else{
        _motionManager.isAccelerometerActive? [_motionManager stopAccelerometerUpdates]:nil;
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorRotation]){
        if([self.motionManager isGyroAvailable] && ![self.motionManager isGyroActive]){
            [self.motionManager startGyroUpdates];
        }
    }else{
        _motionManager.isGyroActive? [_motionManager stopGyroUpdates]:nil;
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeFPS]) {
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
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeBluetooth]) {
        [self bluteeh];
    }
}
-(BOOL)isMonitorTypeAllow:(FTMonitorInfoType)type{
    if (_monitorType & FTMonitorInfoTypeAll || _monitorType & type){
           return YES;
       }
       return NO;
}
-(BOOL)isMonitorMotionTypeAllow:(FTMonitorInfoType)type{
    if (_monitorType & FTMonitorInfoTypeAll ||_monitorType & FTMonitorInfoTypeSensor || _monitorType &  type ){
        return YES;
    }
    return NO;
}
-(void)stopMonitor{
    if (_displayLink) {
        [_displayLink setPaused:YES];
        _displayLink = nil;
    }
    _motionManager.isGyroActive? [_motionManager stopGyroUpdates]:nil;
    _motionManager.isAccelerometerActive? [_motionManager stopAccelerometerUpdates]:nil;
    _motionManager.isMagnetometerActive? [_motionManager stopMagnetometerUpdates]:nil;
    [self stopMonitorProximity];
    [_netFlow stopMonitor];
    [FTURLProtocol stopMonitor];
    [[FTLocationManager sharedInstance] stopUpdatingLocation];
    _pedometer?[_pedometer stopPedometerUpdates]:nil;
    [_session stopRunning];
    [self stopMonitorProximity];
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
#pragma mark -------环境光感-------
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
#pragma mark -------距离传感器-------
-(void)startMonitorProximity{
    UIDevice *device = [UIDevice currentDevice];
    if (device.proximityMonitoringEnabled == NO) {
        device.proximityMonitoringEnabled = YES;
        if (device.proximityMonitoringEnabled == YES) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(proximityChanged:)
                                                         name:UIDeviceProximityStateDidChangeNotification
                                                       object:device];
        }
    }
}
- (void)stopMonitorProximity{
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
}
- (void)proximityChanged:(NSNotification *)notification {
    UIDevice *device = [notification object];
    _proximityState = device.proximityState;
}
#pragma mark -------当天步数-------
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
  WeakSelf
  [_pedometer
      startPedometerUpdatesFromDate:fromDate
                        withHandler:^(CMPedometerData *_Nullable pedometerData,
                                      NSError *_Nullable error) {
      weakSelf.steps = pedometerData.numberOfSteps;
      handler? handler(pedometerData.numberOfSteps, error):nil;
                        }];
}
#pragma mark ========== tag\field 数据拼接 ==========
-(NSDictionary *)getMonitorTagDicts{
        NSMutableDictionary *tag = [NSMutableDictionary new];
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        if ([self isMonitorTypeAllow:FTMonitorInfoTypeBattery]) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:FT_MONITOR_BATTERY_TOTAL];
        }
        if ([self isMonitorTypeAllow:FTMonitorInfoTypeMemory]) {
            [tag setObject:[FTMonitorUtils ft_getTotalMemorySize] forKey:FT_MONITOR_MEMORY_TOTAL];
        }
        if ([self isMonitorTypeAllow:FTMonitorInfoTypeCpu]) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:FT_MONITOR_CPU_NO];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:FT_MONITOR_CPU_HZ];
        }
        if([self isMonitorTypeAllow:FTMonitorInfoTypeGpu]){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:FT_MONITOR_GPU_MODEL];
        }
        if ([self isMonitorTypeAllow:FTMonitorInfoTypeCamera]) {
            [tag setObject:[FTMonitorUtils ft_getFrontCameraPixel] forKey:FT_MONITOR_CAMERA_FRONT_PX];
            [tag setObject:[FTMonitorUtils ft_getBackCameraPixel] forKey:FT_MONITOR_CAMERA_BACK_PX];
        }
        if ([self isMonitorTypeAllow:FTMonitorInfoTypeSystem]) {
            [tag setValue:[FTMonitorUtils userDeviceName] forKey:FT_MONITOR_DEVICE_NAME];
        }
    return tag;
}
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeSystem]) {
        [field setValue:[FTMonitorUtils getLaunchSystemTime] forKey:FT_MONITOR_DEVICE_OPEN_TIME];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeCpu]) {
        [field setObject:[NSNumber numberWithLong:[FTMonitorUtils ft_cpuUsage]] forKey:FT_MONITOR_CPU_USE];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeMemory]) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_usedMemory]] forKey:FT_MONITOR_MEMORY_USE];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeNetwork]) {
        __block NSNumber *network_strength;
        __block NSString *network_type;
        if ([NSThread isMainThread]) {
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
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeBattery]) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_getBatteryUse]] forKey:FT_MONITOR_BATTERY_USE];
        [tag setObject:[FTMonitorUtils ft_batteryStatus] forKey:FT_MONITOR_BATTERY_STATUS];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeGpu]){
        double usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [field setObject:[NSNumber numberWithDouble:usage] forKey:FT_MONITOR_GPU_RATE];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeLocation]) {
        [tag setValue:[FTLocationManager sharedInstance].location.province forKey:FT_MONITOR_PROVINCE];
        [tag setValue:[FTLocationManager sharedInstance].location.city forKey:FT_MONITOR_CITY];
        [tag setValue:[FTLocationManager sharedInstance].location.country forKey:FT_MONITOR_COUNTRY];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.latitude] forKey:FT_MONITOR_LATITUDE];
        [field setValue:[NSNumber numberWithDouble:[FTLocationManager sharedInstance].location.coordinate.longitude] forKey:FT_MONITOR_LONGITUDE];
        NSString *gpsOpen = [[FTLocationManager sharedInstance] gpsServicesEnabled]==0?@"false":@"true";
        [tag setValue:gpsOpen forKey:FT_MONITOR_GPS_OPEN];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorBrightness]) {
        [field setValue:[NSNumber numberWithFloat:[FTMonitorUtils screenBrightness]] forKey:FT_MONITOR_SCREEN_BRIGHTNESS];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorProximity]) {
        [field setValue:[NSNumber numberWithBool:_proximityState]  forKey:FT_MONITOR_PROXIMITY];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeFPS]) {
        [field setValue:[NSNumber numberWithInt:_fps] forKey:FT_MONITOR_FPS];
    }
    if ([self isMonitorTypeAllow:FTMonitorInfoTypeBluetooth]) {
        [field addEntriesFromDictionary:[self getConnectBluetoothIdentifiers]];
        [tag setValue:self.isBlueOn forKey:FT_MONITOR_BT_OPEN];
        
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorTorch]){
        NSString *torch =[FTMonitorUtils getTorchLevel] == 0?@"false":@"true";
        [tag setValue:torch forKey:FT_MONITOR_TORCH];
    }
    if([self.motionManager isGyroAvailable] && ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorRotation])){
        [field addEntriesFromDictionary:@{FT_MONITOR_ROTATION_X:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.x],
                                          FT_MONITOR_ROTATION_Y:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.y],
                                          FT_MONITOR_ROTATION_Z:[NSNumber numberWithDouble:self.motionManager.gyroData.rotationRate.z]}];
    }
    if ([self.motionManager isAccelerometerAvailable]&&([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorAcceleration]) ) {
        [field addEntriesFromDictionary:@{FT_MONITOR_ACCELERATION_X:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.x],
                                          FT_MONITOR_ACCELERATION_Y:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.y],
                                          FT_MONITOR_ACCELERATION_Z:[NSNumber numberWithDouble:self.motionManager.accelerometerData.acceleration.z]}];
    }
    if ([self.motionManager isMagnetometerAvailable]&&([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorMagnetic])) {
        [field addEntriesFromDictionary:@{FT_MONITOR_MAGNETIC_X:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.x],
                                          FT_MONITOR_MAGNETIC_Y:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.y],
                                          FT_MONITOR_MAGNETIC_Z:[NSNumber numberWithDouble:self.motionManager.magnetometerData.magneticField.z]}];
    }
    if(_pedometer && ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorStep])){
        [self startPedometerUpdatesTodayWithHandler:nil];
        [field setValue:self.steps forKey:FT_MONITOR_STEPS];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorLight]){
        [field setValue:[NSNumber numberWithFloat:self.lightValue] forKey:FT_MONITOR_LIGHT];
    }
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
-(NSDictionary *)getConnectBluetoothIdentifiers{
    __block NSMutableDictionary *dict = [NSMutableDictionary new];
    __block NSInteger count = 1;
    if (self.devicesListArray.count>0) {
        [self.devicesListArray enumerateObjectsUsingBlock:^(CBPeripheral * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.state == CBPeripheralStateConnected) {
                [dict setValue:[obj.identifier UUIDString] forKey:[NSString stringWithFormat:@"bt_device%lu",(unsigned long)count]];
                count++;
            }
        }];
    }
    return dict;
}
#pragma mark ========== 蓝牙 ==========
- (void)bluteeh{
    if (!_centralManager) {
        NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
    }
   WeakSelf
    [CBCentralManager aspect_hookSelector:@selector(initWithDelegate:queue:options:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target){
        
        [target aspect_hookSelector:@selector(centralManager:didConnectPeripheral:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> aspectInfo,CBCentralManager *central,CBPeripheral *peripheral){
            if(![weakSelf.devicesListArray containsObject:peripheral])
            [weakSelf.devicesListArray addObject:peripheral];
        } error:NULL];
        [target aspect_hookSelector:@selector(centralManager:didDisconnectPeripheral:error:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> aspectInfo,CBCentralManager *central,CBPeripheral *peripheral){
                   if([weakSelf.devicesListArray containsObject:peripheral])
                   [weakSelf.devicesListArray removeObject:peripheral];
               } error:NULL];
    } error:NULL];
    
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (@available(iOS 10.0, *)) {
        self.isBlueOn = (central.state ==CBManagerStatePoweredOn)? @"true":@"false";
    }
}
#pragma mark ========== 网络请求相关时间/错误率 ==========
-(void)startNetworkingMonitor{
    _monitorNetworking = YES;
}
-(void)stopNetworkingMonitor{
    _monitorNetworking = NO;
}
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    if (@available(iOS 10.0, *)) {
        NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics firstObject];
        NSString *url = [taskMes.request.URL absoluteString];
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
        
        NSData *data = nil;
        [self.lock lock];
        data = self.mutableTaskDatasKeyedByTaskIdentifier[@(task.taskIdentifier)];
        [self.lock unlock];
        if (!_monitorNetworking) {
            return;
        }
        NSDictionary *opdata = @{FT_NETWORK_REQUEST_URL:url,
                                 FT_MONITOR_NETWORK_DNS_TIME:[NSNumber numberWithDouble:dnsTime],
                                 FT_NETWORK_CONNECT_TIME:[NSNumber numberWithDouble:tcpTime],
                                 FT_MONITOR_NETWORK_RESPONSE_TIME:[NSNumber numberWithDouble:responseTime],
                                 FT_NETWORK_DURATION_TIME:[NSNumber numberWithDouble:([taskMes.responseEndDate timeIntervalSinceDate:taskMes.fetchStartDate]*1000)],
                                 FT_NETWORK_RESPONSE_CONTENT:[task.response ft_getResponseContentWithData:data],
        };
        [[FTMobileAgent sharedInstance] netInterceptorWithopdata:opdata];
    }
}
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        _errorNet++;
    }else{
        _successNet++;
    }
    [self.lock lock];
    [self.mutableTaskDatasKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}
- (void)ftHTTPProtocolWithDataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.lock lock];
    if(data){
        self.mutableTaskDatasKeyedByTaskIdentifier[@(dataTask.taskIdentifier)] = data;
    }
    [self.lock unlock];
}
- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
    [self stopFlushTimer];
    [self stopMonitor];
    self.netFlow = nil;
}
@end
