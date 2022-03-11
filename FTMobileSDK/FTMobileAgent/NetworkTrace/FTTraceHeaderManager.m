//
//  FTNetworkTraceManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTTraceHeaderManager.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTWKWebViewHandler.h"
#import "FTURLProtocol.h"
#import "FTNetworkInfoManger.h"
@interface FTTraceHeaderManager ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *skyTraceId;
@property (nonatomic, copy) NSString *skyParentInstance;
@property (nonatomic, assign) FTNetworkTraceType type;
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, assign) int samplerate;
@end
@implementation FTTraceHeaderManager{
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;
}
+ (instancetype)sharedInstance {
    static FTTraceHeaderManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.sdkUrlStr = [FTNetworkInfoManger sharedInstance].metricsUrl;
    }
    return self;
}
- (BOOL)isTraceUrl:(NSURL *)url{
    if (self.sdkUrlStr) {
        return !([url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host]&&[url.port isEqual:[NSURL URLWithString:self.sdkUrlStr].port]);
    }
    return NO;
}
-(void)setNetworkTrace:(FTTraceConfig *)traceConfig {
    self.type = traceConfig.networkTraceType;
    self.samplerate = traceConfig.samplerate;
    self.enableLinkRumData = traceConfig.enableLinkRumData;
    self.networkTraceType = traceConfig.networkTraceType;
    self.enableAutoTrace = traceConfig.enableAutoTrace;
    if (traceConfig.enableAutoTrace) {
        [FTWKWebViewHandler sharedInstance].enableTrace = YES;
        [FTURLProtocol startMonitor];
    }
    
}
- (NSDictionary *)networkTrackHeaderWithUrl:(NSURL *)url{
    // 判断是否是 SDK 的 URL
    if (![self isTraceUrl:url]) {
        return nil;
    }
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.samplerate];
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            return [self getJaegerHeader:sampled];
            break;
        case FTNetworkTraceTypeZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled];
            break;
        case FTNetworkTraceTypeDDtrace:
            return [self getDDTRACEHeader:sampled];
            break;
        case FTNetworkTraceTypeZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled];
            break;
        case FTNetworkTraceTypeSkywalking:
            return [self getSkyWalking_V3Header:sampled url:url];
            break;
        case FTNetworkTraceTypeTraceparent:
            return [self getTraceparentHeader:sampled];
            break;
    }
    return  nil;
}
- (void)getTraceingDatasWithRequestHeaderFields:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if(!handler){
        return;
    }
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            [self getJaegerTraceingDatas:headerFields handler:handler];
            break;
        case FTNetworkTraceTypeZipkinMultiHeader:
            [self getZipkinMultiTraceingDatas:headerFields handler:handler];
            break;
        case FTNetworkTraceTypeDDtrace:
            [self getDDTRACETraceingDatas:headerFields handler:handler];
            break;
        case FTNetworkTraceTypeZipkinSingleHeader:
            [self getZipkinSingleTraceingDatas:headerFields handler:handler];
            break;
        case FTNetworkTraceTypeSkywalking:
            [self getSkyWalking_V3TraceingDatas:headerFields handler:handler];
            break;
        case FTNetworkTraceTypeTraceparent:
            [self getTraceparentTraceingDatas:headerFields handler:handler];
            break;
    }
}
#pragma mark --------- Jaeger ----------
- (NSDictionary *)getJaegerHeader:(BOOL)sampled{
    return @{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",[FTTraceHeaderManager networkTraceID],[FTTraceHeaderManager networkSpanID],@(sampled)]};
}
-(void)getJaegerTraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([[headerFields allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *traceStr =headerFields[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            handler([traceAry firstObject],traceAry[1],[[traceAry lastObject] boolValue]);
        }
    }
}
#pragma mark --------- Zipkin ----------
- (NSDictionary *)getZipkinMultiHeader:(BOOL)sampled{
    return @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
             FT_NETWORK_ZIPKIN_SPANID:[FTTraceHeaderManager networkSpanID],
             FT_NETWORK_ZIPKIN_TRACEID:[FTTraceHeaderManager networkTraceID],
    };
}
- (NSDictionary *)getZipkinSingleHeader:(BOOL)sampled{
    return  @{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",[FTTraceHeaderManager networkTraceID],[FTTraceHeaderManager networkSpanID],[NSString stringWithFormat:@"%d",sampled]]};
}
-(void)getZipkinMultiTraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if ([[headerFields allKeys]containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[[headerFields allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[[headerFields allKeys]containsObject:FT_NETWORK_ZIPKIN_SAMPLED]) {
        NSString *trace = headerFields[FT_NETWORK_ZIPKIN_TRACEID];
        NSString *span = headerFields[FT_NETWORK_ZIPKIN_SPANID];
        NSString *sampling = headerFields[FT_NETWORK_ZIPKIN_SAMPLED];
        handler(trace,span,[sampling boolValue]);
    }
}
-(void)getZipkinSingleTraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([headerFields.allKeys containsObject:FT_NETWORK_ZIPKIN_SINGLE_KEY]){
        NSArray *traceAry = [headerFields[FT_NETWORK_ZIPKIN_SINGLE_KEY] componentsSeparatedByString:@"-"];
        if(traceAry.count == 3){
            NSString *trace = [traceAry firstObject];
            NSString *span = traceAry[1];
            NSString *sampling=traceAry[2];
            handler(trace,span,[sampling boolValue]);
        }
    }
}
#pragma mark --------- DDTRACE ----------
- (NSDictionary *)getDDTRACEHeader:(BOOL)sampled{
    return  @{FT_NETWORK_DDTRACE_ORIGIN:@"rum",
              FT_NETWORK_DDTRACE_SPANID:[NSString stringWithFormat:@"%lld",[self generateUniqueID]],
              FT_NETWORK_DDTRACE_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
              FT_NETWORK_DDTRACE_TRACEID:[NSString stringWithFormat:@"%lld",[self generateUniqueID]]
    };
}
-(void)getDDTRACETraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if ([headerFields.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED] && [headerFields.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID] &&
        [headerFields.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]) {
        NSString *sampling = [headerFields valueForKey:FT_NETWORK_DDTRACE_SAMPLED];
        NSString *trace = [headerFields valueForKey:FT_NETWORK_DDTRACE_TRACEID];
        NSString *span = [headerFields valueForKey:FT_NETWORK_DDTRACE_SPANID];
        handler(trace,span,[sampling boolValue]);
    }
}
- (int64_t)generateUniqueID{
    return arc4random() % (INT64_MAX >> 1);
}
#pragma mark --------- SkyWalking ----------
- (NSDictionary *)getSkyWalking_V2Header:(BOOL)sampled url:(NSURL *)url{
    [self.lock lock];
    NSInteger v2 =  _skywalkingv2 ++;
    [self.lock unlock];
    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)v2,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1] ft_base64Encode];
    NSString *endPoint = [@"-1" ft_base64Encode];
    return @{FT_NETWORK_SKYWALKING_V2:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,@(v2),@(v2),urlStr,endPoint,endPoint]};
}
- (NSDictionary *)getSkyWalking_V3Header:(BOOL)sampled url:(NSURL *)url{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.skyTraceId,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.skyParentInstance,[FTMonitorUtils cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1] ft_base64Encode];
    return @{FT_NETWORK_SKYWALKING_V3:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr]};
}
-(void)getSkyWalking_V2TraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([headerFields.allKeys containsObject:FT_NETWORK_SKYWALKING_V2]){
        NSString *traceStr =headerFields[FT_NETWORK_SKYWALKING_V2];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 9) {
            NSString *sampling = [traceAry firstObject];
            NSString *trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            NSString *span = [parentTraceID stringByAppendingString:@"0"];
            handler(trace,span,[sampling boolValue]);
        }
    }
}
-(void)getSkyWalking_V3TraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([headerFields.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]){
        NSString *traceStr =headerFields[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 8) {
            NSString *sampling = [traceAry firstObject];
            NSString *trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            NSString *span = [parentTraceID stringByAppendingString:@"0"];
            handler(trace,span,[sampling boolValue]);
        }
    }
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

-(NSString *)skyTraceId{
    if (!_skyTraceId) {
        _skyTraceId = [FTTraceHeaderManager networkTraceID];
    }
    return _skyTraceId;
}
-(NSString *)skyParentInstance{
    if (!_skyParentInstance) {
        _skyParentInstance = [FTTraceHeaderManager networkTraceID];
    }
    return _skyParentInstance;
}
#pragma mark --------- traceparent ----------

- (NSDictionary *)getTraceparentHeader:(BOOL)sample{
    NSString *sampleDescion = sample? @"01":@"00";
    return @{FT_NETWORK_TRACEPARENT_KEY:[NSString stringWithFormat:@"%@-%@-%@-%@",@"00",[FTTraceHeaderManager networkTraceID],[FTTraceHeaderManager networkSpanID],sampleDescion]};
}
-(void)getTraceparentTraceingDatas:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([headerFields.allKeys containsObject:FT_NETWORK_TRACEPARENT_KEY]){
        NSString *traceStr =headerFields[FT_NETWORK_TRACEPARENT_KEY];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 4) {
            NSString *trace = traceAry[1];
            NSString *span=traceAry[2];
            NSString *sampling = [traceAry lastObject];
            BOOL sample = [sampling isEqualToString:@"00"]?NO:YES;
            handler(trace,span,sample);
        }
    }
}
#pragma mark --------- traceid、spanid ----------

+(NSString *)networkTraceID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [uuid lowercaseString];
}
+(NSString *)networkSpanID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [[uuid lowercaseString] ft_md5HashToLower16Bit];
}
@end
