//
//  FTNetworkTraceManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTNetworkTraceManager.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTWKWebViewHandler.h"
#import "FTURLProtocol.h"
#import "FTNetworkInfoManger.h"
#import "FTConfigManager.h"
@interface FTNetworkTraceManager ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *skyTraceId;
@property (nonatomic, copy) NSString *skyParentInstance;
@property (nonatomic, assign) FTNetworkTraceType type;
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, assign) int samplerate;
@end
@implementation FTNetworkTraceManager{
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;
}
+ (instancetype)sharedInstance {
    static FTNetworkTraceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        [self setNetworkTrace:FTConfigManager.sharedInstance.traceConfig];
    }
    return self;
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
- (void)networkTrackHeaderWithUrl:(NSURL *)url traceHeader:(TraceHeader)traceHeader{
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.samplerate];
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            [self getJaegerHeader:sampled traceHeader:traceHeader];
            break;
        case FTNetworkTraceTypeZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled traceHeader:traceHeader];
            break;
        case FTNetworkTraceTypeDDtrace:
            return [self getDDTRACEHeader:sampled traceHeader:traceHeader];
            break;
        case FTNetworkTraceTypeZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled traceHeader:traceHeader];
            break;
        case FTNetworkTraceTypeSkywalking:
            return [self getSkyWalking_V3Header:sampled url:url traceHeader:traceHeader];
            break;
        case FTNetworkTraceTypeTraceparent:
            return [self getTraceparentHeader:sampled traceHeader:traceHeader];
            break;
    }
}

#pragma mark --------- Jaeger ----------
- (void)getJaegerHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTNetworkTraceManager networkTraceID];
    NSString *spanid = [FTNetworkTraceManager networkSpanID];
    NSDictionary *header =@{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",traceid,spanid,@(sampled)]};
    traceHeader(traceid,spanid,header);
}
#pragma mark --------- Zipkin ----------
- (void)getZipkinMultiHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTNetworkTraceManager networkTraceID];
    NSString *spanid = [FTNetworkTraceManager networkSpanID];
    NSDictionary *header = @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                             FT_NETWORK_ZIPKIN_SPANID:[FTNetworkTraceManager networkSpanID],
                             FT_NETWORK_ZIPKIN_TRACEID:[FTNetworkTraceManager networkTraceID],
                    };
    traceHeader(traceid,spanid,header);
}
- (void)getZipkinSingleHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTNetworkTraceManager networkTraceID];
    NSString *spanid = [FTNetworkTraceManager networkSpanID];
    NSDictionary *header =@{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",[FTNetworkTraceManager networkTraceID],[FTNetworkTraceManager networkSpanID],[NSString stringWithFormat:@"%d",sampled]]};
    traceHeader(traceid,spanid,header);
}
#pragma mark --------- DDTRACE ----------
- (void)getDDTRACEHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [NSString stringWithFormat:@"%lld",[self generateUniqueID]];
    NSString *spanid = [NSString stringWithFormat:@"%lld",[self generateUniqueID]];
    NSDictionary *header =@{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",[FTNetworkTraceManager networkTraceID],[FTNetworkTraceManager networkSpanID],[NSString stringWithFormat:@"%d",sampled]]};
    traceHeader(traceid,spanid,header);
}
- (int64_t)generateUniqueID{
    return arc4random() % (INT64_MAX >> 1);
}
#pragma mark --------- SkyWalking ----------
- (void)getSkyWalking_V2Header:(BOOL)sampled url:(NSURL *)url traceHeader:(TraceHeader)traceHeader{
    [self.lock lock];
    NSInteger v2 =  _skywalkingv2 ++;
    [self.lock unlock];
    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)v2,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *span = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq];
    NSString *parentTraceId =[span ft_base64Encode];
    NSString *trace = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1];
    NSString *traceId =[trace ft_base64Encode];
    NSString *endPoint = [@"-1" ft_base64Encode];
    NSDictionary *header = @{FT_NETWORK_SKYWALKING_V2:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,@(v2),@(v2),urlStr,endPoint,endPoint]};
    traceHeader(trace,span,header);
}
- (void)getSkyWalking_V3Header:(BOOL)sampled url:(NSURL *)url traceHeader:(TraceHeader)traceHeader{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.skyTraceId,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.skyParentInstance,[FTMonitorUtils cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *spanid = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq];
    NSString *parentTraceId =[spanid ft_base64Encode];
    NSString *trace = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1];
    NSString *traceId =[trace ft_base64Encode];
    NSDictionary *header = @{FT_NETWORK_SKYWALKING_V3:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr]};
    traceHeader(trace,spanid,header);
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
        _skyTraceId = [FTNetworkTraceManager networkTraceID];
    }
    return _skyTraceId;
}
-(NSString *)skyParentInstance{
    if (!_skyParentInstance) {
        _skyParentInstance = [FTNetworkTraceManager networkTraceID];
    }
    return _skyParentInstance;
}
#pragma mark --------- traceparent ----------

- (void)getTraceparentHeader:(BOOL)sample traceHeader:(TraceHeader)traceHeader{
    NSString *sampleDescion = sample? @"01":@"00";
    NSString *spanid = [FTNetworkTraceManager networkSpanID];
    NSString *traceID = [FTNetworkTraceManager networkTraceID];
    NSDictionary *header = @{FT_NETWORK_TRACEPARENT_KEY:[NSString stringWithFormat:@"%@-%@-%@-%@",@"00",[FTNetworkTraceManager networkTraceID],[FTNetworkTraceManager networkSpanID],sampleDescion]};
    traceHeader(traceID,spanid,header);
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
