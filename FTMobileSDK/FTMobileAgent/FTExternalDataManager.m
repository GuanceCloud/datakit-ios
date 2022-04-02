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

-(void)startViewWithName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration{
    [FTGlobalRumManager.sharedInstance.rumManger startViewWithName:viewName viewReferrer:viewReferrer loadDuration:loadDuration];
}
-(void)stopView{
    [FTGlobalRumManager.sharedInstance.rumManger stopView];

}
- (void)addActionWithName:(NSString *)actionName actionType:(NSString *)actionType{
    if ([actionType isEqualToString:@"click"]) {
        [FTGlobalRumManager.sharedInstance.rumManger addClickActionWithName:actionName];
    }
}
- (void)addErrorWithType:(NSString *)type situation:(AppState)situation message:(NSString *)message stack:(NSString *)stack{
    [FTGlobalRumManager.sharedInstance.rumManger addErrorWithType:type situation:situation message:message stack:stack];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    [FTGlobalRumManager.sharedInstance.rumManger addLongTaskWithStack:stack duration:duration];
}
- (void)startResourceWithKey:(NSString *)key{
    [FTGlobalRumManager.sharedInstance.rumManger startResource:key];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    FTTraceHandler *handler = [[FTTraceManager sharedInstance] getTraceHandler:key];
   
    [FTGlobalRumManager.sharedInstance.rumManger addResource:key metrics:metrics content:content spanID:handler.span_id traceID:handler.trace_id];
}

- (void)stopResourceWithKey:(nonnull NSString *)key {
    [FTGlobalRumManager.sharedInstance.rumManger stopResource:key];
}
@end
