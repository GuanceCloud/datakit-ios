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
-(void)stopView{
    [FTGlobalRumManager.sharedInstance stopView];
}
- (void)addClickActionWithName:(NSString *)actionName {
    [FTGlobalRumManager.sharedInstance addClickActionWithName:actionName];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    [FTGlobalRumManager.sharedInstance addActionName:actionName actionType:actionType];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [FTGlobalRumManager.sharedInstance addErrorWithType:type  message:message stack:stack];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    [FTGlobalRumManager.sharedInstance addLongTaskWithStack:stack duration:duration];
}
- (void)startResourceWithKey:(NSString *)key{
    [FTGlobalRumManager.sharedInstance startResourceWithKey:key];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [FTGlobalRumManager.sharedInstance addResourceWithKey:key metrics:metrics content:content];
}
- (void)stopResourceWithKey:(nonnull NSString *)key {
    [FTGlobalRumManager.sharedInstance stopResourceWithKey:key];
}

@end
