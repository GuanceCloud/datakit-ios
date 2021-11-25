//
//  FTExternalResourceManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTExternalResourceManager.h"
#import "FTTraceHandler.h"
#import "FTMonitorManager.h"
#import "FTRUMManager.h"
#import "FTNetworkTrace.h"
#import "FTResourceContentModel.h"
@interface FTExternalResourceManager()
@property (nonatomic, strong) NSMutableDictionary<NSString *,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@end
@implementation FTExternalResourceManager
+ (instancetype)sharedManager{
    static dispatch_once_t onceToken;
    static FTExternalResourceManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTExternalResourceManager alloc]init];
    });
    return sharedManager;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.lock = dispatch_semaphore_create(1);
        self.traceHandlers = [NSMutableDictionary new];
    }
    return self;
}
#pragma mark - Tracing -

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    FTTraceHandler *handler = [self getTraceHandler:key];
    if (!handler) {
        handler = [[FTTraceHandler alloc]initWithUrl:url identifier:key];
        [self setTraceHandler:handler forKey:key];
    }
    return handler.getTraceHeader;
}
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(NSString *)key{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers setValue:handler forKey:key];
    dispatch_semaphore_signal(self.lock);
}
- (FTTraceHandler *)getTraceHandler:(NSString *)key{
    FTTraceHandler *handler = nil;
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    if ([self.traceHandlers.allKeys containsObject:key]) {
      handler = self.traceHandlers[key];
    }
    dispatch_semaphore_signal(self.lock);
    return handler;
}
- (void)removeTraceHandlerWithKey:(NSString *)key{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers removeObjectForKey:key];
    dispatch_semaphore_signal(self.lock);
}
- (void)traceWithKey:(NSString *)key contentModel:(FTResourceContentModel *)model{
    FTTraceHandler *handler = [self getTraceHandler:key];
    if (handler) {
        [handler tracingWithModel:model];
        [self removeTraceHandlerWithKey:key];
    }
}

#pragma mark - Rum -
- (void)startResourceWithKey:(NSString *)key{
    [FTMonitorManager.sharedInstance.rumManger startResource:key];
}
- (void)addResourceWithKey:(NSString *)key contentModel:(FTResourceContentModel *)model{
    __block NSString *traceIdStr,*spanIDStr;
    if([FTNetworkTrace sharedInstance].enableLinkRumData){
        [[FTNetworkTrace sharedInstance] getTraceingDatasWithRequestHeaderFields:model.requestHeader handler:^(NSString * _Nonnull traceId, NSString * _Nonnull spanID, BOOL sampled) {
            traceIdStr = traceId;
            spanIDStr = spanID;
        }];
    }
    [FTMonitorManager.sharedInstance.rumManger addResource:key model:nil content:model spanID:spanIDStr traceID:traceIdStr];
}

- (void)stopResourceWithKey:(nonnull NSString *)key {
    [FTMonitorManager.sharedInstance.rumManger stopResource:key];
}
@end
