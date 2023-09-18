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
-(void)startViewWithName:(NSString *)viewName property:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(startViewWithName:property:)]){
        [self.delegate startViewWithName:viewName property:property];
    }
}
-(void)stopView{
    if(self.delegate && [self.delegate respondsToSelector:@selector(stopView)]){
        [self.delegate stopView];
    }
}
-(void)stopViewWithProperty:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(stopViewWithProperty:)]){
        [self.delegate stopViewWithProperty:property];
    }
}
- (void)addClickActionWithName:(NSString *)actionName {
    if(self.delegate && [self.delegate respondsToSelector:@selector(addClickActionWithName:)]){
        [self.delegate addClickActionWithName:actionName];
    }
}
-(void)addClickActionWithName:(NSString *)actionName property:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addClickActionWithName:property:)]){
        [self.delegate addClickActionWithName:actionName property:property];
    }
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addActionName:actionType:)]){
        [self.delegate addActionName:actionName actionType:actionType];
    }
}
-(void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addActionName:actionType:property:)]){
        [self.delegate addActionName:actionName actionType:actionType property:property];
    }
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:message:stack:)]){
        [self.delegate addErrorWithType:type message:message stack:stack];
    }
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:message:stack:property:)]){
        [self.delegate addErrorWithType:type message:message stack:stack property:property];
    }
}
- (void)addErrorWithType:(nonnull NSString *)type state:(FTAppState)state message:(nonnull NSString *)message stack:(nonnull NSString *)stack property:(nullable NSDictionary *)property {
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:state: message:stack:property:)]){
        [self.delegate addErrorWithType:type state:state message:message stack:stack property:property];
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addLongTaskWithStack:duration:)]){
        [self.delegate addLongTaskWithStack:stack duration:duration];
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(NSDictionary *)property{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addLongTaskWithStack:duration:property:)]){
        [self.delegate addLongTaskWithStack:stack duration:duration property:property];
    }
}
- (void)startResourceWithKey:(NSString *)key{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(startResourceWithKey:)]){
        [self.resourceDelegate startResourceWithKey:key];
    }
}
-(void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(startResourceWithKey:property:)]){
        [self.resourceDelegate startResourceWithKey:key property:property];
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
-(void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(stopResourceWithKey:property:)]){
        [self.resourceDelegate stopResourceWithKey:key property:property];
    }
}
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(getTraceHeaderWithKey:url:)]){
        return [self.resourceDelegate getTraceHeaderWithKey:key url:url];
    }
    return nil;
}
@end
