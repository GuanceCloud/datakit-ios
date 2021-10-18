//
//  FTNetworkTrace.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTNetworkTrace.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTConfigManager.h"
@interface FTNetworkTrace ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, copy) NSString *parentInstance;
@property (nonatomic, assign) FTNetworkTraceType type;
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, assign) int samplerate;
@end
@implementation FTNetworkTrace{
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;
}
+ (instancetype)sharedInstance {
    static FTNetworkTrace *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.sdkUrlStr = [FTConfigManager sharedInstance].trackConfig.metricsUrl;
    }
    return self;
}
- (BOOL)isTraceUrl:(NSURL *)url{
    if (self.sdkUrlStr) {
        return ![url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host];
    }
    return NO;
}
-(void)setNetworkTrace:(FTTraceConfig *)traceConfig {
    self.type = traceConfig.networkTraceType;
    self.samplerate = traceConfig.samplerate;
    self.enableLinkRumData = traceConfig.enableLinkRumData;
    self.service = traceConfig.service;

}
- (NSDictionary *)networkTrackHeaderWithUrl:(NSURL *)url{
    // 用来判断是否开启 trace
    if (!self.service) {
        return nil;
    }
    // 判断是否是 SDK 的 URL
    if (![self isTraceUrl:url]) {
        return nil;
    }
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.samplerate];
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            return @{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",[FTNetworkTrace networkTraceID],[FTNetworkTrace networkSpanID],[NSNumber numberWithBool:sampled]]};
            break;
        case FTNetworkTraceTypeZipkin:
            return @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                     FT_NETWORK_ZIPKIN_SPANID:[FTNetworkTrace networkSpanID],
                     FT_NETWORK_ZIPKIN_TRACEID:[FTNetworkTrace networkTraceID],
            };
            break;
        case FTNetworkTraceTypeDDtrace:
            return @{FT_NETWORK_DDTRACE_ORIGIN:@"rum",
                     FT_NETWORK_DDTRACE_SPANID:[NSString stringWithFormat:@"%lld",[self generateUniqueID]],
                     FT_NETWORK_DDTRACE_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                     FT_NETWORK_DDTRACE_TRACEID:[NSString stringWithFormat:@"%lld",[self generateUniqueID]]
            };
            break;
    }
    return  nil;
}
- (void)getTraceingDatasWithRequestHeaderFields:(NSDictionary *)headerFields handler:(void (^)(NSString *traceId, NSString *spanID,BOOL sampled))handler{
    NSDictionary *header = headerFields;
    NSString *trace,*span,*sampling;
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_TRACEID]) {
        trace = header[FT_NETWORK_ZIPKIN_TRACEID];
        if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]) {
            span = header[FT_NETWORK_ZIPKIN_SPANID];
        }
        if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SAMPLED]) {
            sampling = header[FT_NETWORK_ZIPKIN_SAMPLED] ;
        }
    }else if ([[header allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *traceStr =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            trace = [traceAry firstObject];
            span =traceAry[1];
            sampling = [traceAry lastObject];
        }

    }else if([[header allKeys] containsObject:FT_NETWORK_DDTRACE_TRACEID]){
        sampling = [header valueForKey:FT_NETWORK_DDTRACE_SAMPLED];
        trace = [header valueForKey:FT_NETWORK_DDTRACE_TRACEID];
        span = [header valueForKey:FT_NETWORK_DDTRACE_SPANID];
    }else if ([[header allKeys] containsObject:FT_NETWORK_SKYWALKING_V3]) {
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 8) {
            sampling = [traceAry firstObject];
            trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            span = [parentTraceID stringByAppendingString:@"0"];
        }
    }else if ([[header allKeys] containsObject:FT_NETWORK_SKYWALKING_V2]) {
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V2];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 9) {
            sampling = [traceAry firstObject];
            trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            span = [parentTraceID stringByAppendingString:@"0"];
        }
    }
    if (handler) {
        handler(trace,span,[sampling boolValue]);
    }
}
- (int64_t)generateUniqueID{
    return arc4random() % (INT64_MAX >> 1);
}
- (NSString *)getSkyWalking_V2Str:(BOOL)sampled url:(NSURL *)url{
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
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[NSNumber numberWithInteger:v2],[NSNumber numberWithInteger:v2],urlStr,endPoint,endPoint];
}
- (NSString *)getSkyWalking_V3Str:(BOOL)sampled url:(NSURL *)url{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.traceId,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.parentInstance,[FTMonitorUtils cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *parentTraceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq] ft_base64Encode];
    NSString *traceId =[[basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1] ft_base64Encode];
    return [NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",[NSNumber numberWithBool:sampled],traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr];
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
        _traceId = [FTNetworkTrace networkTraceID];
    }
    return _traceId;
}
-(NSString *)parentInstance{
    if (!_parentInstance) {
        _parentInstance = [FTNetworkTrace networkTraceID];
    }
    return _parentInstance;
}
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
