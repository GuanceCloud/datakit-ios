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
#import "FTDateUtil.h"
#import "FTBaseInfoHandler.h"
@interface FTRUMViewHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) FTRUMContext *sessionContext;
@property (nonatomic, strong) FTRUMActionHandler *actionHandler;
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
@property (nonatomic, assign,readwrite) BOOL isActiveView;

@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) NSDate *viewStartTime;
@property (nonatomic, assign) BOOL needUpdateView;
@end
@implementation FTRUMViewHandler
-(instancetype)initWithModel:(FTRUMViewModel *)model context:(nonnull FTRUMContext *)context{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.view_id = model.view_id;
        self.view_name = model.view_name;
        self.view_referrer = model.view_referrer;
        self.loading_time = model.loading_time;
        self.didReceiveStartData = NO;
        self.viewStartTime = model.time;
        self.resourceHandlers = [NSMutableDictionary new];
        self.sessionContext = context;
        
    }
    return self;
}
- (FTRUMContext *)context{
    FTRUMContext *context = [self.sessionContext copy];
    context.view_name = self.view_name;
    context.view_id = self.view_id;
    context.view_referrer = self.view_referrer;
    context.action_id = self.actionHandler?self.actionHandler.action_id:nil;
    return context;
}
- (BOOL)process:(FTRUMDataModel *)model{
   
    self.needUpdateView = NO;
    self.actionHandler =(FTRUMActionHandler *)[self.assistant manage:(FTRUMHandler *)self.actionHandler byPropagatingData:model];
    switch (model.type) {
        case FTRUMDataViewStart:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                if (self.didReceiveStartData ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartData = YES;
            }else{
                self.needUpdateView = YES;
                self.isActiveView = NO;
            }
            break;
        }
        case FTRUMDataViewStop:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                self.needUpdateView = YES;
                self.isActiveView = NO;
            }
            break;
        }
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
    if (model.type == FTRUMDataResourceError || model.type == FTRUMDataResourceSuccess || model.type == FTRUMDataResourceComplete) {
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
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context];
    actionHandler.handler = ^{
        weakSelf.viewActionCount +=1;
        weakSelf.needUpdateView = YES;
    };
    self.actionHandler = actionHandler;
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc] initWithModel:model context:self.context];
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
    NSDictionary *sessionTag = @{@"session_id":self.context.session_id,
                                 @"session_type":self.context.session_type};
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:data.tags];
    [tags addEntriesFromDictionary:sessionTag];
    [[FTMobileAgent sharedInstance] rumWrite:data.measurement terminal:@"web" tags:tags fields:data.fields tm:data.tm];
}
- (void)writeErrorData:(FTRUMDataModel *)model{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSString *error = model.type == FTRUMDataLongTask?FT_TYPE_LONG_TASK :FT_TYPE_ERROR;
    
    [[FTMobileAgent sharedInstance] rumWrite:error terminal:@"app" tags:tags fields:model.fields];
}
- (void)writeViewData{
    //判断冷启动 冷启动可能没有viewModel
    if (!self.view_id) {
        return;
    }
    NSNumber *timeSpend = [FTDateUtil nanosecondTimeIntervalSinceDate:self.viewStartTime toDate:[NSDate date]];
    NSMutableDictionary *sessionViewTag = [NSMutableDictionary dictionaryWithDictionary:[self.context getGlobalSessionViewTags]];
    [sessionViewTag setValue:[FTBaseInfoHandler boolStr:self.isActiveView] forKey:@"is_active"];
    NSMutableDictionary *field = @{@"view_error_count":@(self.viewErrorCount),
                                   @"view_resource_count":@(self.viewResourceCount),
                                   @"view_long_task_count":@(self.viewLongTaskCount),
                                   @"view_action_count":@(self.viewActionCount),
                                   @"time_spent":timeSpend,
                                   
    }.mutableCopy;
    if (![self.loading_time isEqual:@0]) {
        [field setValue:self.loading_time forKey:@"loading_time"];
    }
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_VIEW terminal:@"app" tags:sessionViewTag fields:field];
}

@end
