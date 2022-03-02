//
//  FTTraceHandlerManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/2.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandlerManager.h"
#import "FTTraceHandler.h"
@interface FTTraceHandlerManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@end
@implementation FTTraceHandlerManager
+ (instancetype)sharedManager{
    static dispatch_once_t onceToken;
    static FTTraceHandlerManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTTraceHandlerManager alloc]init];
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
- (void)traceWithKey:(NSString *)key content:(FTResourceContentModel *)content{
    FTTraceHandler *handler = [self getTraceHandler:key];
    if (handler) {
        [handler tracingWithModel:content];
        [self removeTraceHandlerWithKey:key];
    }
}
@end
