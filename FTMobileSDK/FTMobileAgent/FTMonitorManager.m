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
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#import "FTWKWebViewHandler.h"
#import "FTANRDetector.h"
#define WeakSelf __weak typeof(self) weakSelf = self;
typedef void (^FTPedometerHandler)(NSNumber *pedometerSteps,
NSError *error);
static NSString * const FTUELSessionLockName = @"com.ft.networking.session.manager.lock";

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate, AVCaptureVideoDataOutputSampleBufferDelegate,FTHTTPProtocolDelegate,FTWKWebViewTraceDelegate,FTANRDetectorDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *devicesListArray;
@property (nonatomic, assign) FTMonitorInfoType monitorType;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) FTWKWebViewHandler *webViewHandler;
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSNumber *steps;
@property (nonatomic, assign) NSInteger flushInterval;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) float lightValue;
@property (nonatomic, strong) NSDictionary *blDict;
@property (nonatomic, copy) NSString *isBlueOn;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, copy) NSString *parentInstance;
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
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;

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
        _skywalkingSeq = 0;
    }
    return self;
}
-(void)setMobileConfig:(FTMobileConfig *)config{
    self.config = config;
    if (config.networkTrace) {
        [self dealNetworkContentType:config.networkContentType];
    }
    if (config.networkTrace || config.monitorInfoType | FTMonitorInfoTypeNetwork) {
        [FTURLProtocol startMonitor];
        [FTURLProtocol setDelegate:self];
    }
    [self setMonitorType:config.monitorInfoType];
    if (config.networkTrace) {
        [FTWKWebViewHandler sharedInstance].trace = YES;
        [FTWKWebViewHandler sharedInstance].traceDelegate = self;
    }else{
        [FTWKWebViewHandler sharedInstance].trace = NO;
        [FTWKWebViewHandler sharedInstance].traceDelegate = nil;
    }
    if (config.enableTrackAppANR || _monitorType & FTMonitorInfoTypeFPS) {
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

    if (config.enableTrackAppANR) {
        [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
            [FTANRDetector sharedInstance].delegate = self;
            [[FTANRDetector sharedInstance] startDetecting];
        }];
    }else{
        [FTANRDetector sharedInstance].delegate = nil;
        [[FTANRDetector sharedInstance] stopDetecting];
    }
    
}

-(void)dealNetworkContentType:(NSArray *)array{
    if (array && array.count>0) {
        self.netContentType = [NSSet setWithArray:array];
    }else{
        self.netContentType = [NSSet setWithArray:@[@"application/json",@"application/xml",@"application/javascript",@"text/html",@"text/xml",@"text/plain",@"application/x-www-form-urlencoded",@"multipart/form-data"]];
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
    if (self.flushInterval > 0) {
        [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }];
    }
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
    model.tm =[[NSDate date] ft_dateTimestamp];
    model.op = FTNetworkingTypeMetrics;
    void (^UploadResultBlock)(NSInteger,id) = ^(NSInteger statusCode,id responseObject){
        ZYDebug(@"statusCode == %d\nresponseObject == %@",statusCode,responseObject);
    };
    [[FTMobileAgent sharedInstance] trackUpload:@[model] callBack:UploadResultBlock];
}
-(void)setMonitorType:(FTMonitorInfoType)type{
    _monitorType = type;
    _monitorTagDict = [self getMonitorTagDicts];
    if (type == 0) {
        [self stopFlush];
        [self stopMonitor];
        return;
    }
    if (_monitorType & FTMonitorInfoTypeNetwork) {
        [self startFlushTimer];
    }else{
       [_netFlow stopMonitor];
        if (!self.config.networkTrace) {
           [FTURLProtocol stopMonitor];
        }
    }
    if(_monitorType & FTMonitorInfoTypeLocation){
            [[FTLocationManager sharedInstance] startUpdatingLocation];
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
    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
}
-(BOOL)isMonitorMotionTypeAllow:(FTMonitorInfoType)type{
    if (_monitorType & FTMonitorInfoTypeSensor || _monitorType &  type ){
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
    if (!self.config.networkTrace) {
        [FTURLProtocol stopMonitor];
    }
    [[FTLocationManager sharedInstance] stopUpdatingLocation];
    _pedometer?[_pedometer stopPedometerUpdates]:nil;
    [_session stopRunning];
    [self stopMonitorProximity];
}
-(CMMotionManager *)motionManager{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc]init];
    }
    return _motionManager;
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
    if(_fps<10){
        NSDictionary *field =  @{FT_KEY_EVENT:@"block"};
        [[FTMobileAgent sharedInstance] trackBackground:FT_AUTOTRACK_MEASUREMENT tags:@{FT_AUTO_TRACK_CURRENT_PAGE_NAME:[FTBaseInfoHander ft_getCurrentPageName]} field:field withTrackOP:@"block"];
    }
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
    
    // 创建输入流
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc]initWithDevice:device error:nil];
    
    // 创建设备输出流
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
        if (_monitorType & FTMonitorInfoTypeBattery) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:FT_MONITOR_BATTERY_TOTAL];
        }
        if (_monitorType & FTMonitorInfoTypeMemory) {
            [tag setObject:[FTMonitorUtils ft_getTotalMemorySize] forKey:FT_MONITOR_MEMORY_TOTAL];
        }
        if (_monitorType & FTMonitorInfoTypeCpu) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:FT_MONITOR_CPU_NO];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:FT_MONITOR_CPU_HZ];
        }
        if(_monitorType & FTMonitorInfoTypeGpu){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:FT_MONITOR_GPU_MODEL];
        }
        if (_monitorType & FTMonitorInfoTypeCamera) {
            [tag setObject:[FTMonitorUtils ft_getFrontCameraPixel] forKey:FT_MONITOR_CAMERA_FRONT_PX];
            [tag setObject:[FTMonitorUtils ft_getBackCameraPixel] forKey:FT_MONITOR_CAMERA_BACK_PX];
        }
        if (_monitorType & FTMonitorInfoTypeSystem) {
            [tag setValue:[FTMonitorUtils userDeviceName] forKey:FT_MONITOR_DEVICE_NAME];
        }
    return tag;
}
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];
    if (_monitorType & FTMonitorInfoTypeSystem) {
        [field setValue:[FTMonitorUtils getLaunchSystemTime] forKey:FT_MONITOR_DEVICE_OPEN_TIME];
    }
    if (_monitorType & FTMonitorInfoTypeCpu) {
        [field setObject:[NSNumber numberWithFloat:[FTMonitorUtils ft_cpuUsage]] forKey:FT_MONITOR_CPU_USE];
    }
    if (_monitorType & FTMonitorInfoTypeMemory) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_usedMemory]] forKey:FT_MONITOR_MEMORY_USE];
    }
    if (_monitorType & FTMonitorInfoTypeNetwork) {
        __block NSNumber *network_strength;
        __block NSString *network_type;
        [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
            network_type =[FTNetworkInfo getNetworkType];
            network_strength = [NSNumber numberWithInt:[FTNetworkInfo getNetSignalStrength]];
        }];
        NSString *roam = [FTMonitorUtils getRoamingStates] == NO?FT_KET_FALSE:FT_KEY_TRUE;
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
    if (_monitorType & FTMonitorInfoTypeBattery) {
        [field setObject:[NSNumber numberWithDouble:[FTMonitorUtils ft_getBatteryUse]] forKey:FT_MONITOR_BATTERY_USE];
        [tag setObject:[FTMonitorUtils ft_batteryStatus] forKey:FT_MONITOR_BATTERY_STATUS];
    }
    if (_monitorType & FTMonitorInfoTypeGpu){
        double usage =[[FTGPUUsage new] fetchCurrentGpuUsage];
        [field setObject:[NSNumber numberWithDouble:usage] forKey:FT_MONITOR_GPU_RATE];
    }
    if (_monitorType & FTMonitorInfoTypeLocation) {
        FTLocationInfo *location =[FTLocationManager sharedInstance].location;
        [tag setValue:location.province forKey:FT_MONITOR_PROVINCE];
        [tag setValue:location.city forKey:FT_MONITOR_CITY];
        [tag setValue:location.country forKey:FT_MONITOR_COUNTRY];
        [field setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:FT_MONITOR_LATITUDE];
        [field setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:FT_MONITOR_LONGITUDE];
        NSString *gpsOpen = [[FTLocationManager sharedInstance] gpsServicesEnabled]==0?FT_KET_FALSE:FT_KEY_TRUE;
        [tag setValue:gpsOpen forKey:FT_MONITOR_GPS_OPEN];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorBrightness]) {
        [field setValue:[NSNumber numberWithFloat:[FTMonitorUtils screenBrightness]] forKey:FT_MONITOR_SCREEN_BRIGHTNESS];
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorProximity]) {
        [field setValue:[NSNumber numberWithFloat:_proximityState]  forKey:FT_MONITOR_PROXIMITY];
    }
    if (_monitorType & FTMonitorInfoTypeFPS) {
        [field setValue:[NSNumber numberWithFloat:_fps] forKey:FT_MONITOR_FPS];
    }
    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [field addEntriesFromDictionary:[self getConnectBluetoothIdentifiers]];
        [tag setValue:self.isBlueOn forKey:FT_MONITOR_BT_OPEN];
        
    }
    if ([self isMonitorMotionTypeAllow:FTMonitorInfoTypeSensorTorch]){
        NSString *torch =[FTMonitorUtils getTorchLevel] == 0?FT_KET_FALSE:FT_KEY_TRUE;
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
    if (self.monitorType & FTMonitorInfoTypeNetwork ) {
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
        self.isBlueOn = (central.state ==CBManagerStatePoweredOn)? FT_KEY_TRUE:FT_KET_FALSE;
    }
}
#pragma mark ==========FTHTTPProtocolDelegate 时间/错误率 ==========
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
        NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
        NSTimeInterval dnsTime = [taskMes.domainLookupEndDate timeIntervalSinceDate:taskMes.domainLookupStartDate]*1000;
        NSTimeInterval tcpTime = [taskMes.connectEndDate timeIntervalSinceDate:taskMes.connectStartDate]*1000;
        NSTimeInterval responseTime = [taskMes.responseEndDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
        if(![self trackUrl:task.originalRequest.URL]){
            @synchronized(_lastNetTaskMetrics) {
                _lastNetTaskMetrics = @{FT_MONITOR_FT_NETWORK_DNS_TIME:[NSNumber numberWithInt:dnsTime],
                                        FT_MONITOR_FT_NETWORK_TCP_TIME:[NSNumber numberWithInt:tcpTime],
                                        FT_MONITOR_FT_NETWORK_RESPONSE_TIME:[NSNumber numberWithInt:responseTime]
                };
            }
            return;
        }else{
            @synchronized(_lastNetTaskMetrics) {
                _lastNetTaskMetrics = @{FT_MONITOR_NETWORK_DNS_TIME:[NSNumber numberWithInt:dnsTime],
                                        FT_MONITOR_NETWORK_TCP_TIME:[NSNumber numberWithInt:tcpTime],
                                        FT_MONITOR_NETWORK_RESPONSE_TIME:[NSNumber numberWithInt:responseTime]
                };
            }
        }
}
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        _errorNet++;
    }else{
        NSInteger statusCode = [[task.response ft_getResponseStatusCode] integerValue];
        if (statusCode>=400) {
            _errorNet++;
        }else{
            _successNet++;
        }
    }
}
#pragma mark ========== FTHTTPProtocolDelegate  FTNetworkTrack==========
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task taskDuration:(NSNumber *)duration requestStartDate:(NSDate *)start responseTime:(nonnull NSNumber *)time responseData:(nonnull NSData *)data didCompleteWithError:(nonnull NSError *)error{
    BOOL iserror;
    NSDictionary *responseDict = @{};
    if (error) {
        iserror = YES;
        NSString *errorDescription=[[error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?error.userInfo[@"NSLocalizedDescription"]:@"";
        NSNumber *errorCode = [task.response ft_getResponseStatusCode]?[task.response ft_getResponseStatusCode]:[NSNumber numberWithInteger:error.code];
        responseDict = @{FT_NETWORK_HEADERS:@{},
                                    FT_NETWORK_BODY:@{},
                                    FT_NETWORK_ERROR:@{@"errorCode":[NSNumber numberWithInteger:error.code],
                                                       @"errorDomain":error.domain,
                                                       @"errorDescription":errorDescription,
                                    },
                                    FT_NETWORK_CODE:errorCode,
        };
    }else{
        iserror = [[task.response ft_getResponseStatusCode] integerValue] >=400? YES:NO;
        if (data) {
            responseDict = task.response?[task.response ft_getResponseContentDictWithData:data]:@{};
        }
    }
    NSMutableDictionary *request = [task.currentRequest ft_getRequestContentDict].mutableCopy;
    [request setValue:[task.originalRequest ft_getBodyData:[task.currentRequest ft_isAllowedContentType]] forKey:FT_NETWORK_BODY];
    NSDictionary *response = responseDict?responseDict:@{};
    NSDictionary *content = @{
        FT_NETWORK_RESPONSE_CONTENT:response,
        FT_NETWORK_REQUEST_CONTENT:request
    };
    NSMutableDictionary *tags = @{FT_KEY_OPERATIONNAME:[task.originalRequest ft_getOperationName],
                                  FT_KEY_CLASS:FT_LOGGING_CLASS_TRACING,
                                  FT_KEY_ISERROR:[NSNumber numberWithBool:iserror],
                                  FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
                                  
    }.mutableCopy;
    NSDictionary *field = @{FT_KEY_DURATION:duration};
    __block NSString *trace,*span;
    __block BOOL sampling;
    [task.originalRequest ft_getNetworkTraceingDatas:^(NSString * _Nonnull traceId, NSString * _Nonnull spanID, BOOL sampled) {
        trace = traceId;
        span = spanID;
        sampling = sampled;
    }];
    if(trace&&span&&sampling){
        [tags setValue:trace forKey:FT_FLOW_TRACEID];
        [tags setValue:span forKey:FT_KEY_SPANID];
        [[FTMobileAgent sharedInstance] _loggingBackgroundInsertWithOP:@"networkTrace" status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusInfo] content:[FTBaseInfoHander ft_convertToJsonData:content] tm:[start ft_dateTimestamp] tags:tags field:field];
    }
    [[FTMobileAgent sharedInstance] trackBackground:FT_HTTP_MEASUREMENT tags:@{FT_KEY_HOST:task.originalRequest.URL.host} field:@{FT_NETWORK_REQUEST_URL:task.originalRequest.URL.absoluteString,FT_ISERROR:[NSNumber numberWithInt:iserror],FT_MONITOR_NETWORK_RESPONSE_TIME:time} withTrackOP:FT_HTTP_MEASUREMENT];
}
#pragma mark ========== FTWKWebViewDelegate ==========
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error{
    BOOL iserror = NO;
    NSDictionary *responseDict = @{};
    if (error) {
        iserror = YES;
        NSString *errorDescription=[[error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?error.userInfo[@"NSLocalizedDescription"]:@"";
        NSNumber *errorCode = [NSNumber numberWithInteger:error.code];
        responseDict = @{FT_NETWORK_HEADERS:@{},
                                    FT_NETWORK_BODY:@{},
                                    FT_NETWORK_ERROR:@{@"errorCode":[NSNumber numberWithInteger:error.code],
                                                       @"errorDomain":error.domain,
                                                       @"errorDescription":errorDescription,
                                    },
                                    FT_NETWORK_CODE:errorCode,
        };
    }else{
        iserror = [[response ft_getResponseStatusCode] integerValue] >=400? YES:NO;
    }
    responseDict = response?[response ft_getResponseContentDictWithData:nil]:responseDict;
        NSMutableDictionary *requestDict = [request ft_getRequestContentDict].mutableCopy;
    [requestDict setValue:[request ft_getBodyData:[request ft_isAllowedContentType]] forKey:FT_NETWORK_BODY];
    NSDictionary *responseDic = responseDict?responseDict:@{};
    NSDictionary *content = @{
        FT_NETWORK_RESPONSE_CONTENT:responseDic,
        FT_NETWORK_REQUEST_CONTENT:requestDict
    };
    NSMutableDictionary *tags = @{FT_KEY_OPERATIONNAME:[request ft_getOperationName],
                                  FT_KEY_CLASS:FT_LOGGING_CLASS_TRACING,
                                  FT_KEY_ISERROR:[NSNumber numberWithBool:iserror],
                                  FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
                                  
    }.mutableCopy;
    NSDictionary *field = @{FT_KEY_DURATION:duration};
    __block NSString *trace,*span;
    __block BOOL sampling;
    [request ft_getNetworkTraceingDatas:^(NSString * _Nonnull traceId, NSString * _Nonnull spanID, BOOL sampled) {
        trace = traceId;
        span = spanID;
        sampling = sampled;
    }];
    if(trace&&span&&sampling){
        [tags setValue:trace forKey:FT_FLOW_TRACEID];
        [tags setValue:span forKey:FT_KEY_SPANID];
        [[FTMobileAgent sharedInstance] _loggingBackgroundInsertWithOP:@"networkTrace" status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusInfo] content:[FTBaseInfoHander ft_convertToJsonData:content] tm:[start ft_dateTimestamp] tags:tags field:field];
    }
}
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request isError:(BOOL)isError{
    [[FTMobileAgent sharedInstance] trackBackground:FT_WEB_HTTP_MEASUREMENT tags:@{FT_KEY_HOST:request.URL.host} field:@{FT_NETWORK_REQUEST_URL:request.URL.absoluteString,FT_ISERROR:[NSNumber numberWithInt:isError]} withTrackOP:FT_WEB_HTTP_MEASUREMENT];
}
-(void)ftWKWebViewLoadingWithURL:(NSString *)urlStr duration:(NSNumber *)duration{
    [[FTMobileAgent sharedInstance] trackBackground:FT_WEB_TIMECOST_MEASUREMENT tags:@{FT_AUTO_TRACK_EVENT_ID:[@"loading" ft_md5HashToUpper32Bit]
    } field:@{FT_NETWORK_REQUEST_URL:urlStr,FT_DURATION_TIME:duration,FT_KEY_EVENT:@"loading"} withTrackOP:FT_WEB_TIMECOST_MEASUREMENT];
}
-(void)ftWKWebViewLoadCompletedWithURL:(NSString *)urlStr duration:(NSNumber *)duration{
    [[FTMobileAgent sharedInstance] trackBackground:FT_WEB_TIMECOST_MEASUREMENT tags:@{FT_AUTO_TRACK_EVENT_ID:[@"loadCompleted" ft_md5HashToUpper32Bit]
       } field:@{@"url":urlStr,FT_DURATION_TIME:duration,FT_KEY_EVENT:@"loadCompleted"} withTrackOP:FT_WEB_TIMECOST_MEASUREMENT];
}
#pragma mark ========== FTANRDetectorDelegate ==========
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack{
    [[FTMobileAgent sharedInstance] trackBackground:FT_AUTOTRACK_MEASUREMENT tags:@{FT_AUTO_TRACK_CURRENT_PAGE_NAME:[FTBaseInfoHander ft_getCurrentPageName]} field:@{FT_KEY_EVENT:@"anr"} withTrackOP:@"anr"];
    
    if (slowStack.length>0) {
        NSString *info =[NSString stringWithFormat:@"ANR Stack:\n%@", slowStack];
        [[FTMobileAgent sharedInstance] _loggingExceptionInsertWithContent:info tm:[[NSDate date] ft_dateTimestamp]];
    }
}
#pragma mark ========== FTNetworkTrack ==========
- (BOOL)judgeIsTraceSampling{
    float rate = self.config.traceSamplingRate;
    if(rate<=0){
        return NO;
    }
    if(rate<1){
        int x = arc4random() % 100;
        return x <= (rate*100)? YES:NO;
    }
    return YES;
}
- (BOOL)trackUrl:(NSURL *)url{
    if (self.config.metricsUrl) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.config.metricsUrl].host]&&self.config.networkTrace;
    }
    return NO;
}
- (void)trackUrl:(NSURL *)url completionHandler:(void (^)(BOOL track,BOOL sampled, FTNetworkTraceType type,NSString *skyStr))completionHandler{
    if ([self trackUrl:url]) {
        NSString *skyStr = nil;
        BOOL sample = [self judgeIsTraceSampling];
        if (self.config.networkTraceType == FTNetworkTraceTypeSKYWALKING_V3) {
            skyStr = [self getSkyWalking_V3Str:sample url:url];
        }else if(self.config.networkTraceType == FTNetworkTraceTypeSKYWALKING_V2){
            skyStr = [self getSkyWalking_V2Str:sample url:url];
        }
        if (completionHandler) {
            completionHandler(YES,[self judgeIsTraceSampling],self.config.networkTraceType,skyStr);
        }
    }else{
        if (completionHandler) {
            completionHandler(NO,NO,0,nil);
        }
    }
}
- (NSString *)getSkyWalking_V2Str:(BOOL)sampled url:(NSURL *)url{
    _skywalkingv2 ++;
    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)_skywalkingv2,[self getThreadNumber],[[NSDate date] ft_dateTimestamp]];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1] ft_base64Encode];
    NSString *endPoint = [@"-1" ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[NSNumber numberWithInteger:_skywalkingv2],[NSNumber numberWithInteger:_skywalkingv2],urlStr,endPoint,endPoint];
}
- (NSString *)getSkyWalking_V3Str:(BOOL)sampled url:(NSURL *)url{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.traceId,[self getThreadNumber],[[NSDate date] ft_dateTimestamp]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.parentInstance,[FTMonitorUtils getCELLULARIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1] ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[self.config.traceServiceName ft_base64Encode],parentServiceInstance,urlPath,urlStr];
}
-(NSUInteger)getSkywalkingSeq{
    NSUInteger seq =  _skywalkingSeq;
      _skywalkingSeq += 2 ;
    if (_skywalkingSeq > 9999) {
        _skywalkingSeq = 0;
    }
    return seq;
}
-(NSString *)getThreadNumber{
    NSString *str = [NSThread currentThread].description;
    NSString *chooseStr = @"2";
    while ([str containsString:@"="]) {
        NSRange range = [str rangeOfString:@"="];
        NSRange range1 = [str rangeOfString:@","];
        if (range.location != NSNotFound) {
            NSInteger loc = range.location+1;
            NSInteger len = range1.location - loc;
            chooseStr = [str substringWithRange:NSMakeRange(loc, len )];
            break;
        }
    }
   return [chooseStr ft_removeFrontBackBlank];
}
-(NSString *)traceId{
    if (!_traceId) {
        _traceId = [FTBaseInfoHander ft_getNetworkTraceID];
    }
    return _traceId;
}
-(NSString *)parentInstance{
        if (!_parentInstance) {
            _parentInstance = [FTBaseInfoHander ft_getNetworkTraceID];
        }
        return _parentInstance;
}
#pragma mark ========== 注销 ==========
- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
    [FTWKWebViewHandler sharedInstance].trace = NO;
    [[FTANRDetector sharedInstance] stopDetecting];
    [FTURLProtocol stopMonitor];
    [self stopFlushTimer];
    [self stopMonitor];
    self.netFlow = nil;
}
@end
