//
//  FTRUMManger.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTRUMManager.h"
#import "FTBaseInfoHandler.h"
#import "FTRUMSessionHandler.h"
#import "UIViewController+FTAutoTrack.h"
#import "NSURLResponse+FTMonitor.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTDateUtil.h"
#import "FTLog.h"
#import "FTJSONUtil.h"
#import "FTMobileConfig.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTPresetProperty.h"
@interface FTRUMManager()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, strong) dispatch_queue_t serialQueue;

@end
@implementation FTRUMManager

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig{
    self = [super init];
    if (self) {
        self.rumConfig = rumConfig;
        self.assistant = self;
        self.serialQueue= dispatch_queue_create([@"io.serialQueue.rum" UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
}
#pragma mark - View -
-(void)startView:(UIViewController *)viewController{
    NSString *viewReferrer = viewController.ft_parentVC;
    NSString *viewID = viewController.ft_viewUUID;
    NSString *className = NSStringFromClass(viewController.class);
    //viewModel
    [self startView:viewID viewName:className viewReferrer:viewReferrer loadDuration:viewController.ft_loadDuration];
}
-(void)startView:(NSString *)viewID viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration{
    dispatch_async(self.serialQueue, ^{
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:viewName viewReferrer:viewReferrer];
        viewModel.loading_time = loadDuration;
        viewModel.type = FTRUMDataViewStart;
        [self process:viewModel];
    });
}
-(void)stopView:(UIViewController *)viewController{
    NSString *viewID = viewController.ft_viewUUID;
    [self stopViewWithViewID:viewID];
}
- (void)stopViewWithViewID:(NSString *)viewID{
    dispatch_async(self.serialQueue, ^{
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:@"" viewReferrer:@""];
        viewModel.type = FTRUMDataViewStop;
        [self process:viewModel];
    });
}
#pragma mark - Action -

- (void)addAction:(UIView *)clickView{
    NSString *viewTitle = @"";
    if ([clickView isKindOfClass:UIButton.class]) {
        UIButton *btn =(UIButton *)clickView;
        viewTitle = btn.currentTitle.length>0?[NSString stringWithFormat:@"[%@]",btn.currentTitle]:@"";
    }
    NSString *className = NSStringFromClass(clickView.class);
    NSString *actionName = [NSString stringWithFormat:@"[%@]%@",className,viewTitle];
    [self addActionWithActionName:actionName];
}
- (void)addActionWithActionName:(NSString *)actionName{
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    dispatch_async(self.serialQueue, ^{
        FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:@"click"];
        actionModel.type = FTRUMDataClick;
        [self process:actionModel];
    });
}
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration{
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    dispatch_async(self.serialQueue, ^{
        NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
        NSString *actionType = isHot?@"launch_hot":@"launch_cold";
        FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
        FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithType:type duration:duration];
        launchModel.action_name = actionName;
        launchModel.action_type = actionType;
        [self process:launchModel];
    });
}
- (void)applicationWillTerminate{
    dispatch_sync(self.serialQueue, ^{
    });
}

#pragma mark - Resource -
- (void)resourceStart:(NSString *)identifier{
    dispatch_async(self.serialQueue, ^{
        FTRUMResourceDataModel *resourceStrat = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:identifier];
        
        [self process:resourceStrat];
    });
}
- (void)resourceCompleted:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time{
    dispatch_async(self.serialQueue, ^{
        FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceSuccess identifier:identifier];
        resourceSuccess.time = time;
        resourceSuccess.tags = tags;
        resourceSuccess.fields = fields;
        [self process:resourceSuccess];
    });
}
- (void)resourceError:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time{
    dispatch_async(self.serialQueue, ^{
        FTRUMResourceDataModel *resourceError = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceError identifier:identifier];
        NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:[self errrorMonitorInfo]];
        [newTags addEntriesFromDictionary:tags];
        resourceError.time = time;
        resourceError.tags = newTags;
        resourceError.fields = fields;
        [self process:resourceError];
    });
}
#pragma mark - error 、 long_task -
- (void)addError:(NSDictionary *)tags field:(NSDictionary *)field{
    NSMutableDictionary *errorTag = [NSMutableDictionary dictionaryWithDictionary:tags];
    [errorTag addEntriesFromDictionary:[self errrorMonitorInfo]];
    dispatch_sync(self.serialQueue, ^{
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataError time:[NSDate date]];
        model.tags = errorTag;
        model.fields = field;
        [self process:model];
    });
}
- (void)addLongTask:(NSDictionary *)tags field:(NSDictionary *)field{
    dispatch_async(self.serialQueue, ^{
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:[NSDate date]];
        model.tags = tags;
        model.fields = field;
        [self process:model];
    });
    
}
- (NSDictionary *)errrorMonitorInfo{
    NSMutableDictionary *errorTag = [NSMutableDictionary new];
    FTMonitorInfoType monitorType = self.rumConfig.monitorInfoType;
    if (monitorType & FTMonitorInfoTypeMemory) {
        errorTag[FT_MONITOR_MEMORY_TOTAL] = [FTMonitorUtils totalMemorySize];
        errorTag[FT_MONITOR_MEM_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils usedMemory]];
    }
    if (monitorType & FTMonitorInfoTypeCpu) {
        errorTag[FT_MONITOR_CPU_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
    }
    if (monitorType & FTMonitorInfoTypeBattery) {
        errorTag[FT_MONITOR_POWER] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
    }
    errorTag[@"carrier"] = [FTPresetProperty telephonyInfo];
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    errorTag[@"locale"] = preferredLanguage;
    return errorTag;
}
#pragma mark - webview js -

- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    dispatch_async(self.serialQueue, ^{
        FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
        webModel.tags = tags;
        webModel.fields = fields;
        [self process:webModel];
    });
}

#pragma mark - FTRUMSessionProtocol -
-(BOOL)process:(FTRUMDataModel *)model{
    FTRUMSessionHandler *current  = self.sessionHandler;
    if (current) {
        if ([self manage:self.sessionHandler byPropagatingData:model] == nil) {
            //刷新
            [self.sessionHandler refreshWithDate:model.time];
            [self.sessionHandler.assistant process:model];
        }
    }else{
        //初始化
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model rumConfig:self.rumConfig];
        [self.sessionHandler.assistant process:model];
    }
    
    return YES;
}

-(NSDictionary *)getCurrentSessionInfo{
    return [self.sessionHandler getCurrentSessionInfo];
}
@end
