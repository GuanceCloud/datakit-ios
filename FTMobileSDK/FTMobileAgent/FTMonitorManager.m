//
//  FTMonitorManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTMonitorManager.h"
#import <CoreLocation/CLLocationManager.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "FTLocationManager.h"
#import "FTBaseInfoHander.h"
#import "FTMobileConfig.h"
#import "FTNetworkInfo.h"
#import "FTRecordModel.h"
#import "FTMobileAgent.h"
#import "FTURLProtocol.h"
#import "FTLog.h"
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
#import "FTJSONUtil.h"
#import "FTPresetProperty.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

static NSString * const FTUELSessionLockName = @"com.ft.networking.session.manager.lock";

@interface FTMonitorManager ()<CBCentralManagerDelegate,CBPeripheralDelegate, AVCaptureVideoDataOutputSampleBufferDelegate,FTHTTPProtocolDelegate,FTWKWebViewTraceDelegate,FTANRDetectorDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) FTMonitorInfoType monitorType;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, strong) FTWKWebViewHandler *webViewHandler;
@property (nonatomic, copy) NSString *isBlueOn;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, copy) NSString *parentInstance;
@property (nonatomic, strong) NSLock *lock;

@end

@implementation FTMonitorManager{
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _count;
    float _fps;
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
        _skywalkingSeq = 0;
        self.lock = [NSLock new];
    }
    return self;
}
-(void)setMobileConfig:(FTMobileConfig *)config{
    self.config = config;
        [self dealNetworkContentType:config.networkContentType];
        [FTWKWebViewHandler sharedInstance].trace = YES;
        [FTWKWebViewHandler sharedInstance].traceDelegate = self;
        [FTURLProtocol startMonitor];
        [FTURLProtocol setDelegate:self];
   
    if (_monitorType & FTMonitorInfoTypeFPS) {
        [self setMonitorFPS];
    }else{
        [self endMonitorFPS];
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
    [self setMonitorType:config.monitorInfoType];
}
-(void)dealNetworkContentType:(NSArray *)array{
    if (array && array.count>0) {
        self.netContentType = [NSSet setWithArray:array];
    }else{
        self.netContentType = [NSSet setWithArray:@[@"application/json",@"application/xml",@"application/javascript",@"text/html",@"text/xml",@"text/plain",@"application/x-www-form-urlencoded",@"multipart/form-data"]];
    }
}
-(void)setMonitorType:(FTMonitorInfoType)type{
    _monitorType = type;
    if (type == 0) {
        [self stopMonitor];
        return;
    }
    //位置信息  国家、省、市、经纬度
    (_monitorType & FTMonitorInfoTypeLocation)?[[FTLocationManager sharedInstance] startUpdatingLocation]:[[FTLocationManager sharedInstance] stopUpdatingLocation];

    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
}
-(void)stopMonitor{
    [self endMonitorFPS];
    [[FTLocationManager sharedInstance] stopUpdatingLocation];
}
- (void)startMonitorNetwork{
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:self];
}
#pragma mark ========== FPS ==========
- (void)setMonitorFPS{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)endMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:YES];
        _displayLink = nil;
    }
}
- (void)startMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:NO];
    }
}
- (void)stopMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:YES];
    }
}
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
      
    }
    _count = 0;
}
#pragma mark ========== tag\field 数据拼接 ==========
-(NSDictionary *)getMonitorTagFiledDict{
    NSMutableDictionary *tag = self.monitorTagDict.mutableCopy;//常量监控项
    NSMutableDictionary *field = [[NSMutableDictionary alloc]init];

    if (_monitorType & FTMonitorInfoTypeLocation) {
        FTLocationInfo *location =[FTLocationManager sharedInstance].location;
        [tag setValue:location.province forKey:FT_MONITOR_PROVINCE];
        [tag setValue:location.city forKey:FT_MONITOR_CITY];
        [tag setValue:location.country forKey:FT_MONITOR_COUNTRY];
        [field setValue:[NSNumber numberWithFloat:location.coordinate.latitude] forKey:FT_MONITOR_LATITUDE];
        [field setValue:[NSNumber numberWithFloat:location.coordinate.longitude] forKey:FT_MONITOR_LONGITUDE];
        NSString *gpsOpen = [[FTLocationManager sharedInstance] gpsServicesEnabled]==0?FT_KET_FALSE:FT_KEY_TRUE;
        [tag setValue:gpsOpen forKey:FT_MONITOR_GPS_OPEN];
    }
  
    if (_monitorType & FTMonitorInfoTypeFPS) {
        [field setValue:[NSNumber numberWithFloat:_fps] forKey:FT_MONITOR_FPS];
    }
    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [tag setValue:self.isBlueOn forKey:FT_MONITOR_BT_OPEN];
        
    }
    return @{FT_AGENT_FIELD:field,FT_AGENT_TAGS:tag};
}
#pragma mark ========== 蓝牙 ==========
- (void)bluteeh{
    if (!_centralManager) {
        NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
    }
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (@available(iOS 10.0, *)) {
        self.isBlueOn = (central.state ==CBManagerStatePoweredOn)? FT_KEY_TRUE:FT_KET_FALSE;
    }
}
#pragma mark ==========FTHTTPProtocolDelegate 时间/错误率 ==========
// 监控项采集 网络请求各阶段时间
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
    NSTimeInterval dnsTime = [taskMes.domainLookupEndDate timeIntervalSinceDate:taskMes.domainLookupStartDate]*1000;
    NSTimeInterval tcpTime = [taskMes.secureConnectionStartDate timeIntervalSinceDate:taskMes.connectStartDate]*1000;
    NSTimeInterval tlsTime = [taskMes.secureConnectionEndDate timeIntervalSinceDate:taskMes.secureConnectionStartDate]*1000;
    NSTimeInterval responseTime = [taskMes.responseEndDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
    if([self trackUrl:task.originalRequest.URL]){
       
    }
}
// 监控项采集 网络请求错误率
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
  
}
#pragma mark ========== FTHTTPProtocolDelegate  FTNetworkTrack==========
// 网络请求信息采集 链路追踪
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
        [[FTMobileAgent sharedInstance] _loggingBackgroundInsertWithOP:@"networkTrace" status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusInfo] content:[FTJSONUtil ft_convertToJsonData:content] tm:[start ft_dateTimestamp] tags:tags field:field];
    }
    // 网络请求错误率指标采集
    FTLocationInfo *location =[FTLocationManager sharedInstance].location;
//    [[FTMobileAgent sharedInstance] trackBackground:FT_HTTP_MEASUREMENT
//                                               tags:@{
//                                                   FT_KEY_HOST:task.originalRequest.URL.host,
//                                                   FT_MONITOR_CITY:location.city,
//                                                   FT_MONITOR_PROVINCE:location.province,
//                                                   FT_MONITOR_COUNTRY:location.country,
//                                               } field:@{
//                                                   FT_NETWORK_REQUEST_URL:task.originalRequest.URL.absoluteString,
//                                                   FT_ISERROR:[NSNumber numberWithInt:iserror],
//                                                   FT_MONITOR_NETWORK_RESPONSE_TIME:time,
//                                               } withTrackOP:FT_HTTP_MEASUREMENT];
}
#pragma mark ========== FTWKWebViewDelegate ==========
/**
 * KWebView  网络请求信息采集
 * wkwebview 使用loadRequest 与 reload 发起的请求
 */
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
        [[FTMobileAgent sharedInstance] _loggingBackgroundInsertWithOP:@"networkTrace" status:[FTBaseInfoHander ft_getFTstatueStr:FTStatusInfo] content:[FTJSONUtil ft_convertToJsonData:content] tm:[start ft_dateTimestamp] tags:tags field:field];
    }
}
/**
 * WKWebView 采集错误率 (所有请求)
 */
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request isError:(BOOL)isError{
    
}
/**
 * WKWebView 采集loading时间 (所有请求)
 */
-(void)ftWKWebViewLoadingWithURL:(NSURL *)url duration:(NSNumber *)duration{
    
}
/**
 * WKWebView 采集loadCompleted时间(所有请求)
 */
-(void)ftWKWebViewLoadCompletedWithURL:(NSURL *)url duration:(NSNumber *)duration{
//    [[FTMobileAgent sharedInstance] trackBackground:FT_WEB_TIMECOST_MEASUREMENT
//                                               tags:@{
//                                                   FT_AUTO_TRACK_EVENT_ID:[@"loadCompleted" ft_md5HashToUpper32Bit],
//                                                   FT_NETWORK_REQUEST_URL:url.absoluteString,
//                                                   FT_KEY_HOST:url.host,
//                                               } field:@{
//                                                   FT_DURATION_TIME:duration,
//                                                   FT_KEY_EVENT:@"loadCompleted"
//                                               } withTrackOP:FT_WEB_TIMECOST_MEASUREMENT];
}
#pragma mark ========== FTANRDetectorDelegate ==========
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack{
//    [[FTMobileAgent sharedInstance] trackBackground:FT_AUTOTRACK_MEASUREMENT
//                                               tags:nil field:@{
//                                                   FT_KEY_EVENT:@"anr",
//                                               } withTrackOP:@"anr"];
//    if (slowStack.length>0) {
//        NSString *info =[NSString stringWithFormat:@"ANR Stack:\n%@", slowStack];
//        [[FTMobileAgent sharedInstance] _loggingANRInsertWithContent:info tm:[[NSDate date] ft_dateTimestamp]];
//    }
}
#pragma mark ========== FTNetworkTrack ==========
- (BOOL)trackUrl:(NSURL *)url{
    if (self.config.datawayUrl) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.config.datawayUrl].host]&&self.config.networkTrace;
    }
    return NO;
}
- (void)trackUrl:(NSURL *)url completionHandler:(void (^)(BOOL track,BOOL sampled, FTNetworkTraceType type,NSString *skyStr))completionHandler{
    if ([self trackUrl:url]) {
        NSString *skyStr = nil;
        BOOL sample = [[FTMobileAgent sharedInstance] judgeIsTraceSampling];
        if (self.config.networkTraceType == FTNetworkTraceTypeSKYWALKING_V3) {
            skyStr = [self getSkyWalking_V3Str:sample url:url];
        }else if(self.config.networkTraceType == FTNetworkTraceTypeSKYWALKING_V2){
            skyStr = [self getSkyWalking_V2Str:sample url:url];
        }
        if (completionHandler) {
            completionHandler(YES,sample,self.config.networkTraceType,skyStr);
        }
    }else{
        if (completionHandler) {
            completionHandler(NO,NO,0,nil);
        }
    }
}
- (NSString *)getSkyWalking_V2Str:(BOOL)sampled url:(NSURL *)url{
    [self.lock lock];
    NSInteger v2 =  _skywalkingv2 ++;
    [self.lock unlock];
    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)v2,[self getThreadNumber],[[NSDate date] ft_dateTimestamp]];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1] ft_base64Encode];
    NSString *endPoint = [@"-1" ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[NSNumber numberWithInteger:v2],[NSNumber numberWithInteger:v2],urlStr,endPoint,endPoint];
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
    [self.lock lock];
    NSUInteger seq =  _skywalkingSeq;
    _skywalkingSeq += 2 ;
    if (_skywalkingSeq > 9999) {
        _skywalkingSeq = 0;
    }
    [self.lock unlock];
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
    _config = nil;
    self.monitorTagDict = nil;
    onceToken = 0;
    sharedInstance =nil;
    [FTWKWebViewHandler sharedInstance].trace = NO;
    [[FTANRDetector sharedInstance] stopDetecting];
    [self stopMonitor];
}
@end
