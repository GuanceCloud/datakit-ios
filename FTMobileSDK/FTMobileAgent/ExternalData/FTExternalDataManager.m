//
//  FTExternalResourceManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTExternalDataManager.h"
#import "FTExternalDataManager+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTLog+Private.h"
#import "NSDate+FTUtil.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTConstants.h"
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
-(id<FTRumDatasProtocol>)delegate{
    if(!_delegate){
        FTInnerLogError(@"This operation failed. Please check if RUM is successfully configured.");
    }
    return _delegate;
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
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(startViewWithName:property:)]){
        [self.delegate startViewWithName:viewName property:copyDict];
    }
}
-(void)updateViewLoadingTime:(NSNumber *)duration{
    if(self.delegate && [self.delegate respondsToSelector:@selector(updateViewLoadingTime:)]){
        [self.delegate updateViewLoadingTime:duration];
    }
}
-(void)stopView{
    if(self.delegate && [self.delegate respondsToSelector:@selector(stopView)]){
        [self.delegate stopView];
    }
}
-(void)stopViewWithProperty:(NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(stopViewWithProperty:)]){
        [self.delegate stopViewWithProperty:copyDict];
    }
}
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(startAction:actionType:property:)]){
        [self.delegate startAction:actionName actionType:actionType property:copyDict];
    }
}
- (void)addClickActionWithName:(NSString *)actionName {
    [self startAction:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];
}
-(void)addClickActionWithName:(NSString *)actionName property:(NSDictionary *)property{
    [self startAction:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:property];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    [self startAction:actionName actionType:actionType property:nil];
}
-(void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    [self startAction:actionName actionType:actionType property:property];
}
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(addAction:actionType:property:)]){
        [self.delegate addAction:actionName actionType:actionType property:copyDict];
    }
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:message:stack:)]){
        [self.delegate addErrorWithType:type message:message stack:stack];
    }
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:message:stack:property:)]){
        [self.delegate addErrorWithType:type message:message stack:stack property:copyDict];
    }
}
- (void)addErrorWithType:(nonnull NSString *)type state:(FTAppState)state message:(nonnull NSString *)message stack:(nonnull NSString *)stack property:(nullable NSDictionary *)property {
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(addErrorWithType:state: message:stack:property:)]){
        [self.delegate addErrorWithType:type state:state message:message stack:stack property:copyDict];
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - [duration longLongValue];
    if(self.delegate && [self.delegate respondsToSelector:@selector(addLongTaskWithStack:duration:startTime:)]){
        [self.delegate addLongTaskWithStack:stack duration:duration startTime:startTime];
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(NSDictionary *)property{
    long long startTime = [NSDate ft_currentNanosecondTimeStamp] - [duration longLongValue];
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.delegate && [self.delegate respondsToSelector:@selector(addLongTaskWithStack:duration:startTime:property:)]){
        [self.delegate addLongTaskWithStack:stack duration:duration startTime:startTime  property:copyDict];
    }
}
- (void)startResourceWithKey:(NSString *)key{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(startResourceWithKey:)]){
        [self.resourceDelegate startResourceWithKey:key];
    }
}
-(void)startResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(startResourceWithKey:property:)]){
        [self.resourceDelegate startResourceWithKey:key property:copyDict];
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
    NSDictionary *copyDict = [property ft_deepCopy];
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(stopResourceWithKey:property:)]){
        [self.resourceDelegate stopResourceWithKey:key property:copyDict];
    }
}
- (nullable NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(getTraceHeaderWithUrl:)]){
        return [self.resourceDelegate getTraceHeaderWithUrl:url];
    }
    return nil;
}
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    if(self.resourceDelegate && [self.resourceDelegate respondsToSelector:@selector(getTraceHeaderWithKey:url:)]){
        return [self.resourceDelegate getTraceHeaderWithKey:key url:url];
    }
    return nil;
}
@end
