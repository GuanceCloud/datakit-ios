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
#import "FTCallStack.h"
#import "FTWeakProxy.h"
#import "FTPingThread.h"
#import "FTNetworkTrace.h"
#import "FTTaskInterceptionModel.h"
#import "FTWKWebViewJavascriptBridge.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTMonitorManager ()<CBCentralManagerDelegate,FTHTTPProtocolDelegate,FTANRDetectorDelegate,FTWKWebViewTraceDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) FTWKWebViewHandler *webViewHandler;
@property (nonatomic, strong) FTPingThread *pingThread;
@property (nonatomic, strong) FTNetworkTrace *trace;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTWKWebViewJavascriptBridge *jsBridge;
@end

@implementation FTMonitorManager{
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _count;
    float _fps;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (config.enableTrackAppFreeze) {
            [self startPingThread];
        }else{
            [self stopPingThread];
        }
        if (config.monitorInfoType & FTMonitorInfoTypeFPS) {
            [self startMonitorFPS];
        }else{
            [self stopMonitorFPS];
        }
        if (config.enableTrackAppANR) {
            [FTANRDetector sharedInstance].delegate = self;
            [[FTANRDetector sharedInstance] startDetecting];
        }
    });
    if (config.monitorInfoType & FTMonitorInfoTypeBluetooth) {
        [self bluteeh];
    }
    self.trace = [[FTNetworkTrace alloc]initWithType:config.networkTraceType];
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
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    if (!self.config.enableTrackAppFreeze || ![agent judgeIsTraceSampling]) {
        return;
    }
    NSMutableDictionary *fields = @{@"duration":@"-1"}.mutableCopy;
   
    fields[@"long_task_stack"] = stack;
    if (self.sessionSourceDelegate && [self.sessionSourceDelegate respondsToSelector:@selector(ftLongTaskWithtags:field:)]) {
        [self.sessionSourceDelegate ftLongTaskWithtags:@{} field:fields];
    }}
-(void)stopMonitor{
    [FTURLProtocol stopMonitor];
    [self stopMonitorFPS];
    [self stopPingThread];
}
- (void)startMonitorNetwork{
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:[FTWeakProxy proxyWithTarget:self]];
}
- (NSNumber *)fpsValue{
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
- (void)ftTaskCreateWith:(FTTaskInterceptionModel *)taskModel{
    if (self.sessionSourceDelegate && [self.sessionSourceDelegate respondsToSelector:@selector(ftResourceCreate:)]) {
        [self.sessionSourceDelegate ftResourceCreate:taskModel];
    }

}
- (void)ftTaskInterceptionCompleted:(FTTaskInterceptionModel *)taskModel{
    // network trace
    [self networkTraceWithTask:taskModel.task didFinishCollectingMetrics:taskModel.metrics didCompleteWithError:taskModel.error];
    
    // rum resourc
    if (![[FTMobileAgent sharedInstance] judgeIsTraceSampling]) {
        return;
    }
    
    if (self.sessionSourceDelegate && [self.sessionSourceDelegate respondsToSelector:@selector(ftResourceCompleted:)]) {
        [self.sessionSourceDelegate ftResourceCompleted:taskModel];
    }
}
// 网络请求信息采集 链路追踪
- (void)networkTraceWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics didCompleteWithError:(NSError *)error{
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
    if (self.config.networkTrace) {
        FTStatus status = FTStatusOk;
        NSDictionary *responseDict = @{};
        if (error) {
            status = FTStatusError;
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
                status = FTStatusError;
            }
            responseDict = task.response?[task.response ft_getResponseDict]:@{};
        }
        NSString *statusStr = [FTBaseInfoHander statusStrWithStatus:status];

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
            [agent tracing:[FTJSONUtil convertToJsonData:content] tags:tags field:field tm:[taskMes.requestStartDate ft_dateTimestamp]];
        }
    }

}
#pragma mark == FTWKWebViewDelegate ==
/**
 * KWebView  网络请求信息采集
 * wkwebview 使用loadRequest 与 reload 发起的请求
 */
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error{
    FTStatus status = FTStatusOk;
    NSDictionary *responseDict = @{};
    if (error) {
        status = FTStatusError;
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
            status = FTStatusError;
        }
        responseDict = response?[response ft_getResponseDict]:responseDict;
    }
    NSString *statusStr = [FTBaseInfoHander statusStrWithStatus:status];
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
    [[FTMobileAgent sharedInstance] tracing:[FTJSONUtil convertToJsonData:content] tags:tags field:field tm:[start ft_dateTimestamp]];
}
#pragma mark - jsBridge -
-(void)ftAddScriptMessageHandlerWithWebView:(WKWebView *)webView{
    if (![webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    self.jsBridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView];
    [self.jsBridge registerHandler:@"sendEvent" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self dealReceiveScriptMessage:data callBack:responseCallback];
    }];
}
- (void)dealReceiveScriptMessage:(id )message callBack:(WVJBResponseCallback)callBack{
      @try {
        NSDictionary *messageDic = [FTJSONUtil dictionaryWithJsonString:message];
        if (![messageDic isKindOfClass:[NSDictionary class]]) {
            ZYErrorLog(@"Message body is formatted failure from JS SDK");
            return;
        }
        NSString *name = messageDic[@"name"];
        if([name isEqualToString:@"serverVerify"]){
            
            
        }else if ([name isEqualToString:@"rum"]||[name isEqualToString:@"track"]||[name isEqualToString:@"log"]||[name isEqualToString:@"trace"]) {
            NSDictionary *data = messageDic[@"data"];
            NSString *measurement = data[@"measurement"];
            NSDictionary *tags = data[@"tags"];
            NSDictionary *fields = data[@"fields"];
            long long time = [data[@"time"] longLongValue];
            time = time>0?:[[NSDate date] ft_dateTimestamp];
            if (measurement && fields.count>0) {
                if ([name isEqualToString:@"rum"]) {
                    if (self.sessionSourceDelegate && [self.sessionSourceDelegate respondsToSelector:@selector(ftWebviewDataWithMeasurement:tags:fields:tm:)]) {
                        [self.sessionSourceDelegate ftWebviewDataWithMeasurement:measurement tags:tags fields:fields tm:time];
                    }
                }else if([name isEqualToString:@"track"]){
//                    [[FTMobileAgent sharedInstance] rumTrack:measurement tags:tags fields:fields tm:time];
                }else if([name isEqualToString:@"log"]){
                    //数据格式需要调整
                }else if([name isEqualToString:@"trace"]){
//                    [[FTMobileAgent sharedInstance] tracing:measurement tags:tags field:fields tm:time];

                }
            }
        }
        
      
          
        
    } @catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
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
    int duration = (int)(MXRMonitorRunloopOneStandstillMillisecond*MXRMonitorRunloopStandstillCount/1000);
    NSMutableDictionary *fields = @{@"duration":[NSNumber numberWithInt:duration]}.mutableCopy;
    fields[@"long_task_stack"] = slowStack;
    if ([agent judgeRUMTraceOpen]) {
        if (self.sessionSourceDelegate && [self.sessionSourceDelegate respondsToSelector:@selector(ftLongTaskWithtags:field:)]) {
            [self.sessionSourceDelegate ftLongTaskWithtags:@{} field:fields];
        }
    }else{
    [agent loggingWithType:FTAddDataCache status:FTStatusCritical content:slowStack tags:@{FT_APPLICATION_UUID:[FTBaseInfoHander applicationUUID]} field:nil tm:time];
    }
}
#pragma mark ========== FTNetworkTrack ==========
- (BOOL)trackUrl:(NSURL *)url{
    if (self.config.metricsUrl) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.config.metricsUrl].host];
    }
    return NO;
}
- (void)trackUrl:(NSURL *)url completionHandler:(void (^)(NSDictionary *traceHeader))completionHandler{
    if ([self trackUrl:url] && self.config.networkTrace) {
        BOOL sample = [[FTMobileAgent sharedInstance] judgeIsTraceSampling];
        NSDictionary *dict = [self.trace networkTrackHeaderWithSampled:sample url:url];
        if (completionHandler) {
            completionHandler(dict);
        }
    }else{
        if (completionHandler) {
            completionHandler(nil);
        }
    }
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
