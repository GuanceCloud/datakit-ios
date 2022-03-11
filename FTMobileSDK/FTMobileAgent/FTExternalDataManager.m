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
#pragma mark - Tracing -
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    return  [[FTTraceHeaderManager sharedInstance] networkTrackHeaderWithUrl:url];
}
#pragma mark - Rum -

-(void)startViewWithName:(NSString *)viewName  loadDuration:(NSNumber *)loadDuration{
    [FTGlobalRumManager.sharedInstance.rumManger startViewWithName:viewName loadDuration:loadDuration];
}
-(void)stopView{
    [FTGlobalRumManager.sharedInstance.rumManger stopView];
}
- (void)addClickActionWithName:(NSString *)actionName {
        [FTGlobalRumManager.sharedInstance.rumManger addClickActionWithName:actionName];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [FTGlobalRumManager.sharedInstance.rumManger addErrorWithType:type  message:message stack:stack];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    [FTGlobalRumManager.sharedInstance.rumManger addLongTaskWithStack:stack duration:duration];
}
- (void)startResourceWithKey:(NSString *)key{
    [FTGlobalRumManager.sharedInstance.rumManger startResource:key];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    
    [FTGlobalRumManager.sharedInstance.rumManger addResource:key metrics:metrics content:content];
}
- (void)stopResourceWithKey:(nonnull NSString *)key {
    [FTGlobalRumManager.sharedInstance.rumManger stopResource:key];
}

@end
