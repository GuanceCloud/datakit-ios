//
//  FTExternalResourceManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTExternalDataManager.h"
#import "FTExternalDataManager+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
@interface FTExternalDataManager()
@property (nonatomic, weak) id <FTRumDatasProtocol> delegate;
@property (nonatomic, weak) id <FTExternalResourceProtocol> resourceDelegate;
@property (nonatomic, weak) id <FTTracerProtocol> traceDelegate;
@end
@implementation FTExternalDataManager
+ (instancetype)sharedManager{
    static dispatch_once_t onceToken;
    static FTExternalDataManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTExternalDataManager alloc]init];
    });
    return sharedManager;
}
#pragma mark - Rum -
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    if(self.delegate && [self.delegate respondsToSelector:@selector(onCreateView:loadTime:)]){
        [self.delegate onCreateView:viewName loadTime:loadTime];
    }
}
-(void)startViewWithName:(NSString *)viewName {
    if(self.delegate && [self.delegate respondsToSelector:@selector(startViewWithName:)]){
        [self.delegate startViewWithName:viewName];
    }
}
-(void)stopView{
    if(self.delegate && [self.delegate respondsToSelector:@selector(stopView)]){
        [self.delegate stopView];
    }
}
- (void)addClickActionWithName:(NSString *)actionName {
    if(self.delegate && [self.delegate respondsToSelector:@selector(addClickActionWithName:)]){
        [self.delegate addClickActionWithName:actionName];
    }
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addActionName:actionType:)]){
        [self.delegate addActionName:actionName actionType:actionType];
    }
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:message:stack:)]){
        [self.delegate addErrorWithType:type message:message stack:stack];
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addLongTaskWithStack:duration:)]){
        [self.delegate addLongTaskWithStack:stack duration:duration];
    }
}
- (void)startResourceWithKey:(NSString *)key{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(startResourceWithKey:)]){
        [self.resourceDelegate startResourceWithKey:key];
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(addResourceWithKey:metrics:content:)]){
        [self.resourceDelegate addResourceWithKey:key metrics:metrics content:content];
    }
}
- (void)stopResourceWithKey:(nonnull NSString *)key {
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(stopResourceWithKey:)]){
        [self.resourceDelegate stopResourceWithKey:key];
    }
}
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(getTraceHeaderWithKey:url:)]){
        return [self.resourceDelegate getTraceHeaderWithKey:key url:url];
    }
    return nil;
}
@end
