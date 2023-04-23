//
//  FTTraceManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTTraceManager.h"
#import "FTNetworkInfoManager.h"
#import "FTTraceHandler.h"
#import "FTConfigManager.h"
@interface FTTraceManager ()
@property (nonatomic,copy) NSString *sdkUrlStr;
@property (nonatomic, strong) NSMutableDictionary<NSString *,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) BOOL enableLinkRumData;
@end
@implementation FTTraceManager
+ (instancetype)sharedInstance {
    static FTTraceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.sdkUrlStr = [FTNetworkInfoManager sharedInstance].metricsUrl;
        self.lock = dispatch_semaphore_create(1);
        self.traceHandlers = [NSMutableDictionary new];
    }
    return self;
}
-(BOOL)enableAutoTrace{
    return [FTConfigManager sharedInstance].traceConfig.enableAutoTrace;
}
-(BOOL)enableLinkRumData{
    return  [FTConfigManager sharedInstance].traceConfig.enableLinkRumData;
}
- (BOOL)isTraceUrl:(NSURL *)url{
    BOOL trace = NO;
    if (self.sdkUrlStr) {
        if (url.port!=nil) {
            trace = !([url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host]&&[url.port isEqual:[NSURL URLWithString:self.sdkUrlStr].port]);
        }else{
            trace = ![url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host];
        }
        if(trace && self.intakeUrl){
            return self.intakeUrl(url);
        }
    }
    return trace;
}
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    FTTraceHandler *handler = [self getTraceHandler:key];
    if (!handler) {
        handler = [[FTTraceHandler alloc]initWithUrl:url identifier:key];
        if(self.enableLinkRumData){
        [self setTraceHandler:handler forKey:key];
        }
    }
    return handler.getTraceHeader;
}
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(NSString *)key{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers setValue:handler forKey:key];
    dispatch_semaphore_signal(self.lock);
}
// 因为不涉及 trace 数据写入 调用-getTraceHandler方法的仅是 rum 操作 需要确保 rum 调用此方法
- (FTTraceHandler *)getTraceHandler:(NSString *)key{
    FTTraceHandler *handler = nil;
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    if ([self.traceHandlers.allKeys containsObject:key]) {
      handler = self.traceHandlers[key];
      [self.traceHandlers removeObjectForKey:key];
    }
    dispatch_semaphore_signal(self.lock);
    return handler;
}
-(void)removeTraceHandlerWithKey:(NSString *)key{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers removeObjectForKey:key];
    dispatch_semaphore_signal(self.lock);
}
@end
