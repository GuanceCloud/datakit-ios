//
//  FTExternalResourceManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTExternalDataManager.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTTraceHeaderManager.h"
#import "FTResourceContentModel.h"
#import "FTTraceHandler.h"
#import "FTTraceManager.h"
@interface FTExternalDataManager()

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
    [FTGlobalRumManager.sharedInstance onCreateView:viewName loadTime:loadTime];
}
-(void)startViewWithName:(NSString *)viewName {
    [FTGlobalRumManager.sharedInstance startViewWithName:viewName];
}
-(void)startViewWithName:(NSString *)viewName context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance startViewWithName:viewName context:context];
}
- (void)stopView{
    [FTGlobalRumManager.sharedInstance stopView];
}
-(void)stopViewWithContext:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance stopViewWithContext:context];
}
- (void)addClickActionWithName:(NSString *)actionName {
    [FTGlobalRumManager.sharedInstance addClickActionWithName:actionName];
}
- (void)addClickActionWithName:(NSString *)actionName context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance addClickActionWithName:actionName context:context];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    [FTGlobalRumManager.sharedInstance addActionName:actionName actionType:actionType];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance addActionName:actionName actionType:actionType context:context];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [FTGlobalRumManager.sharedInstance addErrorWithType:type  message:message stack:stack];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance addErrorWithType:type  message:message stack:stack context:context];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    [FTGlobalRumManager.sharedInstance addLongTaskWithStack:stack duration:duration];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance addLongTaskWithStack:stack duration:duration context:context];
}
- (void)startResourceWithKey:(NSString *)key{
    [FTGlobalRumManager.sharedInstance startResourceWithKey:key];
}
- (void)startResourceWithKey:(NSString *)key context:(NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance startResourceWithKey:key context:context];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [FTGlobalRumManager.sharedInstance addResourceWithKey:key metrics:metrics content:content];
}
- (void)stopResourceWithKey:(nonnull NSString *)key {
    [FTGlobalRumManager.sharedInstance stopResourceWithKey:key];
}
- (void)stopResourceWithKey:(nonnull NSString *)key context:(nullable NSDictionary *)context{
    [FTGlobalRumManager.sharedInstance stopResourceWithKey:key context:context];
}

@end
