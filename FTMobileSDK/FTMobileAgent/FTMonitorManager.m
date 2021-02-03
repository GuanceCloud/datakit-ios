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
#include <netdb.h>
#include <arpa/inet.h>
#import "FTWeakProxy.h"
#import "FTPingThread.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTMonitorManager ()<CBCentralManagerDelegate,FTHTTPProtocolDelegate,FTANRDetectorDelegate,FTWKWebViewTraceDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, assign) FTMonitorInfoType monitorType;

@property (nonatomic, strong) FTWKWebViewHandler *webViewHandler;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, copy) NSString *parentInstance;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) FTPingThread *pingThread;
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
    if (config.enableTrackAppFreeze) {
        [self startPingThread];
    }else{
        [self stopPingThread];
    }
    if (self.monitorType & FTMonitorInfoTypeFPS) {
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
    if (_monitorType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
}
-(FTPingThread *)pingThread{
    if (!_pingThread || _pingThread.isCancelled) {
        _pingThread = [[FTPingThread alloc]init];
        WeakSelf
        _pingThread.block = ^(NSString * _Nonnull stackStr) {
            [weakSelf trackAppFreeze:stackStr];
        };
    }
    return _pingThread;
}
-(void)startPingThread{
    if (!self.pingThread.isExecuting) {
        [self.pingThread start];
    }
}
-(void)stopPingThread{
    if (_pingThread && _pingThread.isExecuting) {
        [self.pingThread cancel];
    }
}
- (void)trackAppFreeze:(NSString *)stack{
    long long time = [[NSDate date] ft_dateTimestamp];
    
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    if (!self.config.enableTrackAppFreeze || ![agent judgeIsTraceSampling]) {
        return;
    }
    NSDictionary *tag = @{@"freeze_type":@"Freeze"};
    NSMutableDictionary *fields = @{@"freeze_duration":@"-1"}.mutableCopy;
    [agent  rumTrack:@"rum_app_freeze" tags:tag fields:fields tm:time];
    fields[@"freeze_stack"] = stack;
    [agent rumTrackES:FT_TYPE_FREEZE terminal:@"app" tags:tag fields:fields tm:time];
}
-(void)dealNetworkContentType:(NSArray *)array{
    if (array && array.count>0) {
        self.netContentType = [NSSet setWithArray:array];
    }else{
        self.netContentType = [NSSet setWithArray:@[@"application/json",@"application/xml",@"application/javascript",@"text/html",@"text/xml",@"text/plain",@"application/x-www-form-urlencoded",@"multipart/form-data"]];
    }
}
-(void)stopMonitor{
    [FTURLProtocol stopMonitor];
    [self stopMonitorFPS];
}
- (void)startMonitorNetwork{
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:[FTWeakProxy proxyWithTarget:self]];
}
- (NSNumber *)getFPSValue{
    return [NSNumber numberWithFloat:_fps];
}
#pragma mark ========== FPS ==========
- (void)startMonitorFPS{
    if (_displayLink) {
        [_displayLink setPaused:NO];
    }else{
        _displayLink = [CADisplayLink displayLinkWithTarget:[FTWeakProxy proxyWithTarget:self] selector:@selector(tick:)];
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
        [_displayLink invalidate];
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
        NSString *statusStr = [FTBaseInfoHander ft_getFTstatueStr:FTStatusOk];
        NSDictionary *responseDict = @{};
        if (error) {
            statusStr = [FTBaseInfoHander ft_getFTstatueStr:FTStatusError];
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
            if( [[task.response ft_getResponseStatusCode] integerValue] >=400){
                statusStr =[FTBaseInfoHander ft_getFTstatueStr:FTStatusError];
            }
            responseDict = task.response?[task.response ft_getResponseDict]:@{};
        }
        NSMutableDictionary *request = [task.currentRequest ft_getRequestContentDict].mutableCopy;
        NSDictionary *response = responseDict?responseDict:@{};
        NSDictionary *content = @{
            FT_NETWORK_RESPONSE_CONTENT:response,
            FT_NETWORK_REQUEST_CONTENT:request
        };
        NSMutableDictionary *tags = @{FT_KEY_OPERATION:[task.originalRequest ft_getOperationName],
                                      FT_TRACING_STATUS:statusStr,
                                      FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
        }.mutableCopy;
        NSDictionary *field = @{FT_KEY_DURATION:[NSNumber numberWithInt:[metrics.taskInterval duration]*1000000]};
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
            [agent tracing:[FTJSONUtil ft_convertToJsonData:content] tags:tags field:field tm:[taskMes.requestStartDate ft_dateTimestamp]];
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
    if ([responseHeader.allKeys containsObject:@"Proxy-Connection"]) {
        tags[@"response_connection"] =responseHeader[@"Proxy-Connection"];
    }
    tags[@"resource_type"] = response.MIMEType;
    NSString *response_server = [self getIPWithHostName:task.originalRequest.URL.host];
    if (response_server) {
        tags[@"response_server"] = response_server;
    }
    
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
    NSNumber *dnsTime = [taskMes.domainLookupEndDate ft_nanotimeIntervalSinceDate:taskMes.domainLookupStartDate];
    NSNumber *tcpTime = [taskMes.connectEndDate ft_nanotimeIntervalSinceDate:taskMes.connectStartDate];
    NSNumber *tlsTime = taskMes.secureConnectionStartDate!=nil ? [taskMes.connectEndDate ft_nanotimeIntervalSinceDate:taskMes.secureConnectionStartDate]:@0;
    NSNumber *ttfbTime = [taskMes.responseStartDate ft_nanotimeIntervalSinceDate:taskMes.requestStartDate];
    NSNumber *transTime =[taskMes.responseEndDate ft_nanotimeIntervalSinceDate:taskMes.requestStartDate];
    NSNumber *durationTime = [taskMes.requestEndDate ft_nanotimeIntervalSinceDate:taskMes.fetchStartDate];
    fields[@"resource_size"] =[NSNumber numberWithLongLong:task.countOfBytesReceived];
    fields[@"resource_load"] =durationTime;
    fields[@"resource_dns"] = dnsTime;
    fields[@"resource_tcp"] = tcpTime;
    fields[@"resource_ssl"] = tlsTime;
    fields[@"resource_ttfb"] = ttfbTime;
    fields[@"resource_trans"] = transTime;
    
    [agent rumTrack:@"rum_app_resource_performance" tags:tags fields:fields];
    if (response) {
        fields[@"response_header"] =[FTBaseInfoHander ft_getDictStr:response.allHeaderFields];
        fields[@"request_header"] = [FTBaseInfoHander ft_getDictStr:[task.currentRequest ft_getRequestHeaders]];
    }
    tags[@"resource_url"] = task.originalRequest.URL.absoluteString;
    tags[@"resource_url_path"] = task.originalRequest.URL.path;
    [agent rumTrackES:FT_TYPE_RESOURCE terminal:FT_TERMINAL_APP tags:tags fields:fields];
    
}
#pragma mark == FTWKWebViewDelegate ==
/**
 * KWebView  网络请求信息采集
 * wkwebview 使用loadRequest 与 reload 发起的请求
 */
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error{
    NSString *statusStr = [FTBaseInfoHander ft_getFTstatueStr:FTStatusOk];
    NSDictionary *responseDict = @{};
    if (error) {
        statusStr = [FTBaseInfoHander ft_getFTstatueStr:FTStatusError];
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
        if( [[response ft_getResponseStatusCode] integerValue] >=400){
            statusStr =[FTBaseInfoHander ft_getFTstatueStr:FTStatusError];
        }
        responseDict = response?[response ft_getResponseDict]:responseDict;
    }
    NSMutableDictionary *requestDict = [request ft_getRequestContentDict].mutableCopy;
    NSDictionary *responseDic = responseDict?responseDict:@{};
    NSDictionary *content = @{
        FT_NETWORK_RESPONSE_CONTENT:responseDic,
        FT_NETWORK_REQUEST_CONTENT:requestDict
    };
    NSMutableDictionary *tags = @{FT_KEY_OPERATION:[request ft_getOperationName],
                                  FT_TRACING_STATUS:statusStr,
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
    [[FTMobileAgent sharedInstance] tracing:[FTJSONUtil ft_convertToJsonData:content] tags:tags field:field tm:[start ft_dateTimestamp]];
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
        [agent rumTrackES:FT_TYPE_FREEZE terminal:FT_TERMINAL_APP tags:tag fields:fields tm:time];
    }else{
    [agent loggingWithType:FTAddDataCache status:FTStatusCritical content:slowStack tags:@{FT_APPLICATION_UUID:[FTBaseInfoHander ft_getApplicationUUID]} field:nil tm:time];
    }
}
#pragma mark ========== FTNetworkTrack ==========
- (BOOL)trackUrl:(NSURL *)url{
    if (self.config.metricsUrl) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.config.metricsUrl].host];
    }
    return NO;
}
- (void)trackUrl:(NSURL *)url completionHandler:(void (^)(BOOL track,BOOL sampled, FTNetworkTraceType type,NSString *skyStr))completionHandler{
    if ([self trackUrl:url] && self.config.networkTrace) {
        NSString *skyStr = nil;
        BOOL sample = [[FTMobileAgent sharedInstance] judgeIsTraceSampling];
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
    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)v2,[self getThreadNumber],[[NSDate date] ft_msDateTimestamp]];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1] ft_base64Encode];
    NSString *endPoint = [@"-1" ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[NSNumber numberWithInteger:v2],[NSNumber numberWithInteger:v2],urlStr,endPoint,endPoint];
}
- (NSString *)getSkyWalking_V3Str:(BOOL)sampled url:(NSURL *)url{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.traceId,[self getThreadNumber],[[NSDate date] ft_msDateTimestamp]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.parentInstance,[FTMonitorUtils getCELLULARIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1] ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[self.config.serviceName ft_base64Encode],parentServiceInstance,urlPath,urlStr];
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
-(NSString *)getIPWithHostName:(const NSString *)hostName{
    const char *hostN= [hostName UTF8String];
    struct hostent* phot;
    @try {
        phot = gethostbyname(hostN);
    }
    @catch (NSException *exception) {
        return nil;
    }
    struct in_addr ip_addr;
    memcpy(&ip_addr, phot->h_addr_list[0], 4);
    char ip[20] = {0};
    inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));
    NSString* strIPAddress = [NSString stringWithUTF8String:ip];
    return strIPAddress;
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
