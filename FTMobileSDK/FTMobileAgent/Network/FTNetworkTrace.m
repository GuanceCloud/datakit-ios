//
//  FTNetworkTrace.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTNetworkTrace.h"
#import "NSDate+FTAdd.h"
#import "NSString+FTAdd.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
@interface FTNetworkTrace ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, copy) NSString *parentInstance;
@property (nonatomic, assign) FTNetworkTraceType type;
@end
@implementation FTNetworkTrace{
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;
}
-(instancetype)initWithType:(FTNetworkTraceType)type{
    self = [super init];
    if (self) {
        _type = type;
    }
    return self;
}
- (NSDictionary *)networkTrackHeaderWithSampled:(BOOL)sampled url:(NSURL *)url{
    
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            return @{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",[FTNetworkTrace networkTraceID],[FTNetworkTrace networkSpanID],[NSNumber numberWithBool:sampled]]};
            break;
        case FTNetworkTraceTypeZipkin:
            return @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                     FT_NETWORK_ZIPKIN_SPANID:[FTNetworkTrace networkSpanID],
                     FT_NETWORK_ZIPKIN_TRACEID:[FTNetworkTrace networkSpanID],
            };
            break;
    }
    return  nil;
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
