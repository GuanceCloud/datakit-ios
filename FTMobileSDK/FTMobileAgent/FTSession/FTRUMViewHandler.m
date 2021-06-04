//
//  FTRUMViewHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
#import "FTRUMResourceHandler.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "NSDate+FTAdd.h"
#import "FTBaseInfoHander.h"
@interface FTRUMViewHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMActionHandler *actionHandler;
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;

@property (nonatomic, copy) NSString *viewid;
@property (nonatomic, assign,readwrite) BOOL isActiveView;
@property (nonatomic, strong) FTRUMViewModel *viewModel;
@property (nonatomic, strong) FTRUMSessionModel *sessionModel;

@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) NSDate *viewStartTime;
@property (nonatomic, assign) BOOL needUpdateView;
@end
@implementation FTRUMViewHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.viewid = model.baseViewData.view_id;
        self.viewModel = model.baseViewData;
        self.sessionModel = model.baseSessionData;
        self.didReceiveStartData = NO;
        self.viewStartTime = model.time;
        self.resourceHandlers = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)process:(FTRUMDataModel *)model{
    model.baseViewData = self.viewModel;
    self.needUpdateView = NO;
    self.actionHandler =(FTRUMActionHandler *)[self.assistant manage:(FTRUMHandler *)self.actionHandler byPropagatingData:model];
    switch (model.type) {
        case FTRUMDataViewStart:
            if (self.viewid && [self.viewid isEqualToString:model.baseViewData.view_id]) {
                if (self.didReceiveStartData ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartData = YES;
            }else{
                self.needUpdateView = YES;
                self.isActiveView = NO;
            }
            break;
        case FTRUMDataViewStop:
            if (self.viewid && [self.viewid isEqualToString:model.baseViewData.view_id]) {
                self.needUpdateView = YES;
                self.isActiveView = NO;
            }
            break;
        case FTRUMDataClick:{
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }
        }
            break;
        case FTRUMDataLaunchCold:{
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }
        }
            break;
        case FTRUMDataLaunchHot:{
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }
        }
            break;
        case FTRUMDataError:{
            if (self.isActiveView) {
                self.viewErrorCount++;
                model.baseActionData = self.actionHandler.model.baseActionData;
                [self writeErrorData:model];
                [self.actionHandler writeActionData:[NSDate date]];
                self.needUpdateView = YES;
            }
            break;
        }
        case FTRUMDataResourceStart:
            if (self.isActiveView) {
                [self startResource:(FTRUMResourceDataModel *)model];
            }
            break;
        case FTRUMDataLongTask:{
            if (self.isActiveView) {
                model.baseActionData = self.actionHandler.model.baseActionData;
                self.viewLongTaskCount++;
                [self writeErrorData:model];
                self.needUpdateView = YES;
            }
        }
            break;
        case FTRUMDataWebViewJSBData:{
            if (self.isActiveView) {
                [self writeWebViewJSBData:(FTRUMWebViewData *)model];
            }
        }
        default:
            break;
    }
    if (model.type == FTRUMDataResourceError || model.type == FTRUMDataResourceSuccess) {
        FTRUMResourceDataModel *newModel = (FTRUMResourceDataModel *)model;
        
        FTRUMResourceHandler *handler =  self.resourceHandlers[newModel.identifier];
        self.resourceHandlers[newModel.identifier] =[handler.assistant manage:handler byPropagatingData:model];
    }
    
    BOOL hasNoPendingResources = self.resourceHandlers.count == 0;
    BOOL shouldComplete = !self.isActiveView && hasNoPendingResources;
    if (shouldComplete) {
        [self.actionHandler writeActionData:[NSDate date]];
    }
    if (self.needUpdateView) {
        [self writeViewData];
    }
    return !shouldComplete;
}
- (void)startAction:(FTRUMDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:model];
    actionHandler.handler = ^{
        weakSelf.viewActionCount +=1;
        weakSelf.needUpdateView = YES;
    };
    self.actionHandler = actionHandler;
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc]initWithModel:model];
    resourceHandler.errorHandler = ^(){
        weakSelf.viewErrorCount +=1;
        weakSelf.needUpdateView = YES;
    };
    resourceHandler.resourceHandler = ^{
        weakSelf.viewResourceCount+=1;
        weakSelf.needUpdateView = YES;
    };
    self.resourceHandlers[model.identifier] =resourceHandler;
}
- (void)writeWebViewJSBData:(FTRUMWebViewData *)data{
    NSDictionary *sessionTag = @{@"session_id":self.sessionModel.session_id,
                                 @"session_type":self.sessionModel.session_type};
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:data.tags];
    [tags addEntriesFromDictionary:sessionTag];
    [[FTMobileAgent sharedInstance] rumWrite:data.measurement terminal:@"web" tags:tags fields:data.fields tm:data.tm];
}
- (void)writeErrorData:(FTRUMDataModel *)model{
    //判断冷启动 冷启动可能没有viewModel
    NSDictionary *viewTag = self.viewModel?@{@"view_id":self.viewModel.view_id,
                                             @"view_referrer":self.viewModel.view_referrer,
                                             @"view_name":self.viewModel.view_name,
    }:@{};
    NSDictionary *sessionTag = @{@"session_id":self.sessionModel.session_id,
                                 @"session_type":self.sessionModel.session_type};
    //产生error数据时 判断是否有action
    NSDictionary *actionTag =model.baseActionData? @{@"action_id":model.baseActionData.action_id,
                                                     @"action_name":model.baseActionData.action_name,
                                                     @"action_type":model.baseActionData.action_type,
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actionTag];
    [tags addEntriesFromDictionary:model.tags];
    NSString *error = model.type == FTRUMDataLongTask?FT_TYPE_LONG_TASK :FT_TYPE_ERROR;
    
    [[FTMobileAgent sharedInstance] rumWrite:error terminal:@"app" tags:tags fields:model.fields];
}
- (void)writeViewData{
    //判断冷启动 冷启动可能没有viewModel
    if (!self.viewModel) {
        return;
    }
    NSNumber *timeSpend = [[NSDate date] ft_nanotimeIntervalSinceDate:self.viewStartTime];
    NSDictionary *tags = @{@"view_id":self.viewModel.view_id,
                           @"is_active":[FTBaseInfoHander boolStr:self.isActiveView],
                           @"view_referrer":self.viewModel.view_referrer,
                           @"view_name":self.viewModel.view_name,
                           @"session_id":self.sessionModel.session_id,
                           @"session_type":self.sessionModel.session_type,
    };
    NSMutableDictionary *field = @{@"view_error_count":@(self.viewErrorCount),
                                   @"view_resource_count":@(self.viewResourceCount),
                                   @"view_long_task_count":@(self.viewLongTaskCount),
                                   @"view_action_count":@(self.viewActionCount),
                                   @"time_spent":timeSpend,
                                   
    }.mutableCopy;
    if (![self.viewModel.loading_time isEqual:@0]) {
        [field setValue:self.viewModel.loading_time forKey:@"loading_time"];
    }
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_VIEW terminal:@"app" tags:tags fields:field];
}

@end
