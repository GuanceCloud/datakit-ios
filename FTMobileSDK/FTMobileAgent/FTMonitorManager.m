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
#import "FTMobileAgent.h"
#import "FTURLProtocol.h"
#import "FTLog.h"
#import "FTMonitorUtils.h"
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
#import "FTCallStack.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTMonitorManager ()<CBCentralManagerDelegate,FTHTTPProtocolDelegate,FTANRDetectorDelegate,FTWKWebViewTraceDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) FTMonitorInfoType monitorType;

@property (nonatomic, strong) FTWKWebViewHandler *webViewHandler;
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
    [self startMonitorNetwork];
    if (config.networkTrace) {
        [FTWKWebViewHandler sharedInstance].trace = YES;
        [FTWKWebViewHandler sharedInstance].traceDelegate = self;
    }else{
        [FTWKWebViewHandler sharedInstance].trace = NO;
        [FTWKWebViewHandler sharedInstance].traceDelegate = nil;
    }
    if (self.monitorType & FTMonitorInfoTypeFPS || self.config.enableTrackAppUIBlock) {
        [self startMonitorFPS];
    }else{
        [self stopMonitorFPS];
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
    //位置信息  国家、省、市、经纬度
    (_monitorType & FTMonitorInfoTypeLocation)?[[FTLocationManager sharedInstance] startUpdatingLocation]:[[FTLocationManager sharedInstance] stopUpdatingLocation];
    
    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
}
-(void)dealNetworkContentType:(NSArray *)array{
    if (array && array.count>0) {
        self.netContentType = [NSSet setWithArray:array];
    }else{
        self.netContentType = [NSSet setWithArray:@[@"application/json",@"application/xml",@"application/javascript",@"text/html",@"text/xml",@"text/plain",@"application/x-www-form-urlencoded",@"multipart/form-data"]];
    }
}
-(void)stopMonitor{
    [self stopMonitorFPS];
    [[FTLocationManager sharedInstance] stopUpdatingLocation];
}
- (void)startMonitorNetwork{
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:self];
}
- (NSNumber *)getFPSValue{
    return [NSNumber numberWithFloat:_fps];
}
#pragma mark ========== FPS ==========
- (void)startMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:NO];
    }else{
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)pauseMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:YES];
    }
}
- (void)stopMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:YES];
        _displayLink = nil;
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
    _count = 0;
    if(_fps<10){
        [self trackAppFreeze];
    }
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
        self.isBlueOn = central.state ==CBManagerStatePoweredOn;
    }
}
#pragma mark ==========FTHTTPProtocolDelegate 时间/错误率 ==========
// 网络请求信息采集 链路追踪
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics didCompleteWithError:(NSError *)error{
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
    if (self.config.networkTrace) {
        BOOL iserror;
        NSDictionary *responseDict = @{};
        if (error) {
            iserror = YES;
            NSString *errorDescription=[[error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?error.userInfo[@"NSLocalizedDescription"]:@"";
            NSNumber *errorCode = [task.response ft_getResponseStatusCode]?[task.response ft_getResponseStatusCode]:[NSNumber numberWithInteger:error.code];
            
            responseDict = @{FT_NETWORK_HEADERS:@{},
                             FT_NETWORK_ERROR:@{@"errorCode":[NSNumber numberWithInteger:error.code],
                                                
                                                @"errorDomain":error.domain,
                                                
                                                @"errorDescription":errorDescription,
                                                
                             },
                             FT_NETWORK_CODE:errorCode,
            };
        }else{
            iserror = [[task.response ft_getResponseStatusCode] integerValue] >=400? YES:NO;
            responseDict = task.response?[task.response ft_getResponseDict]:@{};
        }
        NSMutableDictionary *request = [task.currentRequest ft_getRequestContentDict].mutableCopy;
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
        NSDictionary *field = @{FT_KEY_DURATION:[NSNumber numberWithInt:[metrics.taskInterval duration]*1000*1000]};
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
            [agent loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil ft_convertToJsonData:content] tags:tags field:field tm:[taskMes.requestStartDate ft_dateTimestamp]];
        }
    }
    if (![agent judgeIsTraceSampling] || error) {
        return;
    }
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    NSDictionary *responseHeader = response.allHeaderFields;
    NSMutableDictionary *tags = [NSMutableDictionary new];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    tags[@"resource_url_host"] = task.originalRequest.URL.host;
    tags[@"resource_url_path"] = task.originalRequest.URL.path;
    if ([responseHeader.allKeys containsObject:@"Proxy-Connection"]) {
        tags[@"response_connection"] =responseHeader[@"Proxy-Connection"];
    }
    tags[@"resource_type"] = response.MIMEType;
//    @"response_server";
    tags[@"response_content_type"] =response.MIMEType;
    if ([responseHeader.allKeys containsObject:@"Content-Encoding"]) {
        tags[@"response_content_encoding"] = responseHeader[@"Content-Encoding"];
    }
    tags[@"resource_method"] = task.originalRequest.HTTPMethod;
    tags[@"resource_status"] = [response ft_getResponseStatusCode];
    NSString *group =  [response ft_getResourceStatusGroup];
    if (group) {
        tags[@"resource_status_group"] = group;
    }
    NSTimeInterval dnsTime = [taskMes.domainLookupEndDate timeIntervalSinceDate:taskMes.domainLookupStartDate]*1000;
    NSTimeInterval tcpTime = [taskMes.connectEndDate timeIntervalSinceDate:taskMes.connectStartDate]*1000;
    NSTimeInterval tlsTime = taskMes.secureConnectionStartDate!=nil ? [taskMes.connectEndDate timeIntervalSinceDate:taskMes.secureConnectionStartDate]*1000:0;
    NSTimeInterval ttfbTime = [taskMes.responseStartDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
    NSTimeInterval transTime =[taskMes.responseEndDate timeIntervalSinceDate:taskMes.requestStartDate]*1000;
    NSTimeInterval durationTime = [taskMes.requestEndDate timeIntervalSinceDate:taskMes.fetchStartDate]*1000;
    fields[@"resource_size"] =[NSNumber numberWithLongLong:task.countOfBytesReceived];
    fields[@"resource_load"] =[NSNumber numberWithInt:durationTime];
    fields[@"resource_dns"] = [NSNumber numberWithInt:dnsTime];
    fields[@"resource_tcp"] = [NSNumber numberWithInt:tcpTime];
    fields[@"resource_ssl"] = [NSNumber numberWithInt:tlsTime];
    fields[@"resource_ttfb"] = [NSNumber numberWithInt:ttfbTime];
    fields[@"resource_trans"] = [NSNumber numberWithInt:transTime];
    
    [agent rumTrack:@"rum_app_resource_performance" tags:tags fields:fields];
    if (response) {
        fields[@"response_header"] =[FTBaseInfoHander ft_getDictStr:response.allHeaderFields];
        fields[@"request_header"] = [FTBaseInfoHander ft_getDictStr:[task.currentRequest ft_getRequestHeaders]];
    }
    [agent rumTrackES:@"resource" terminal:@"app" tags:tags fields:fields];
    
}
#pragma mark == FTWKWebViewDelegate ==
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
    responseDict = response?[response ft_getResponseDict]:responseDict;
    NSMutableDictionary *requestDict = [request ft_getRequestContentDict].mutableCopy;
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
    }
    [[FTMobileAgent sharedInstance] loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil ft_convertToJsonData:content] tags:tags field:field tm:[start ft_dateTimestamp]];
}
- (void)trackAppFreeze{
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    if (![agent judgeIsTraceSampling]) {
        return;
    }
    NSString  *freeze_stack = [FTCallStack ft_backtraceOfMainThread];
    long long time = [[NSDate date] ft_dateTimestamp];
    NSDictionary *tag = @{@"freeze_type":@"Freeze"};
    NSMutableDictionary *fields = @{@"freeze_duration":@"-1"}.mutableCopy;
    [agent  rumTrack:@"rum_app_freeze" tags:tag fields:fields tm:time];
    fields[@"freeze_stack"] = freeze_stack;
    [agent rumTrackES:@"freeze" terminal:@"app" tags:tag fields:fields tm:time];
}
#pragma mark ========== FTANRDetectorDelegate ==========
- (void)onMainThreadSlowStackDetected:(NSString*)slowStack{
    if (!self.config.enableTrackAppANR || slowStack.length==0) {
        return;
    }
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    if (![agent judgeIsTraceSampling]) {
        return;
    }
    long long time = [[NSDate date] ft_dateTimestamp];
    NSDictionary *tag = @{@"freeze_type":@"ANR"};
    int duration = (int)(MXRMonitorRunloopOneStandstillMillisecond*MXRMonitorRunloopStandstillCount/1000);
    NSMutableDictionary *fields = @{@"freeze_duration":[NSNumber numberWithInt:duration]}.mutableCopy;
    [agent  rumTrack:@"rum_app_freeze" tags:tag fields:fields tm:time];
    fields[@"freeze_stack"] = slowStack;
    if ([agent judgeRUMTraceOpen]) {
        [agent rumTrackES:@"freeze" terminal:@"app" tags:tag fields:fields tm:time];
    }else{
    [agent loggingWithType:FTAddDataCache status:FTStatusCritical content:slowStack tags:@{FT_APPLICATION_UUID:[FTBaseInfoHander ft_getApplicationUUID]} field:nil tm:time];
    }
}
#pragma mark ========== FTNetworkTrack ==========
- (BOOL)trackUrl:(NSURL *)url{
    if (self.config.metricsUrl) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.config.metricsUrl].host]&&self.config.networkTrace;
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
    onceToken = 0;
    sharedInstance =nil;
    [FTWKWebViewHandler sharedInstance].trace = NO;
    [[FTANRDetector sharedInstance] stopDetecting];
    [self stopMonitor];
}
@end
