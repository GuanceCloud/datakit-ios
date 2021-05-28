//
//  FTRUMViewScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMViewScope.h"
#import "FTRUMActionScope.h"
#import "FTRUMResourceScope.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
@interface FTRUMViewScope()<FTRUMScopeProtocol>
@property (nonatomic, strong) FTRUMActionScope *actionScope;
@property (nonatomic, strong) NSMutableDictionary *resourceScopes;

@property (nonatomic, copy) NSString *viewid;
@property (nonatomic, assign,readwrite) BOOL isActiveView;
@property (nonatomic, strong) FTRUMViewModel *viewModel;
@property (nonatomic, strong) FTRUMSessionModel *sessionModel;

@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartCommand;
@end
@implementation FTRUMViewScope
-(instancetype)initWithModel:(FTRUMCommand *)model{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.viewid = model.baseViewData.view_id;
        self.viewModel = model.baseViewData;
        self.sessionModel = model.baseSessionData;
        self.didReceiveStartCommand = NO;
        self.resourceScopes = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)process:(FTRUMCommand *)command{
    command.baseViewData = self.viewModel;
    self.actionScope =(FTRUMActionScope *)[self.assistant manage:(FTRUMScope *)self.actionScope byPropagatingCommand:command];
    switch (command.type) {
        case FTRUMDataViewStart:
            if (self.viewid && [self.viewid isEqualToString:command.baseViewData.view_id]) {
                if (self.didReceiveStartCommand ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartCommand = YES;
                if (self.isActiveView && self.actionScope == nil) {
                    [self startAction:command];
                }
            }else{
            self.isActiveView = NO;
            }
            break;
        case FTRUMDataViewStop:
            self.isActiveView = NO;
            if (self.actionScope == nil) {
                [self startAction:command];
            }
            break;
        case FTRUMDataClick:{
            if (self.isActiveView && self.actionScope == nil) {
                [self startAction:command];
            }
        }
            break;
        case FTRUMDataLaunchCold:{
            if (self.isActiveView && self.actionScope == nil) {
                [self startAction:command];
            }
        }
            break;
        case FTRUMDataLaunchHot:{
            if (self.isActiveView && self.actionScope == nil) {
                [self startAction:command];
            }
        }
            break;
        case FTRUMDataViewError:
            if (self.isActiveView) {
                command.baseActionData = self.actionScope.command.baseActionData;
                self.viewErrorCount++;
                [self writeErrorData:command];
            }
            break;
        case FTRUMDataViewResourceStart:
            if (self.isActiveView) {
                [self startResource:(FTRUMResourceCommand *)command];
            }
            break;
        case FTRUMDataViewLongTask:{
            if (self.isActiveView) {
                command.baseActionData = self.actionScope.command.baseActionData;
                self.viewLongTaskCount++;
                [self writeErrorData:command];
            }
        }
        default:
            break;
    }
    if (command.type == FTRUMDataViewResourceError || command.type == FTRUMDataViewResourceSuccess||command.type ==FTRUMDataViewResourceStart) {
        FTRUMResourceCommand *reCommand = (FTRUMResourceCommand *)command;
        
        FTRUMResourceScope *scope =  self.resourceScopes[reCommand.identifier];
        self.resourceScopes[reCommand.identifier] =[scope.assistant manage:scope byPropagatingCommand:command];
    }
    
    BOOL hasNoPendingResources = self.resourceScopes.count == 0;
    BOOL shouldComplete = !self.isActiveView && hasNoPendingResources;
    if (shouldComplete) {
        [self writeViewData];
    }
    return !shouldComplete;
}
- (void)startAction:(FTRUMCommand *)command{
    __weak typeof(self) weakSelf = self;
    FTRUMActionScope *actionScope = [[FTRUMActionScope alloc]initWithCommand:command parent:self];
    actionScope.handler = ^{
        weakSelf.viewActionCount +=1;
    };
    self.actionScope = actionScope;
}
- (void)startResource:(FTRUMResourceCommand *)command{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceScope *scope = [[FTRUMResourceScope alloc]initWithCommand:command parent:self];
    scope.errorHandler = ^(){
        weakSelf.viewErrorCount +=1;
    };
    scope.resourceHandler = ^{
        weakSelf.viewResourceCount+=1;
    };
    self.resourceScopes[command.identifier] =scope;
}

- (void)writeErrorData:(FTRUMCommand *)command{
    //判断冷启动 冷启动可能没有viewModel
    NSDictionary *viewTag = self.viewModel?@{@"view_id":self.viewModel.view_id,
                                             @"is_active":@(self.isActiveView),
                                             @"view_referrer":self.viewModel.view_referrer,
                                             @"view_name":self.viewModel.view_name,
    }:@{};
    NSDictionary *sessionTag = @{@"session_id":self.sessionModel.session_id,
                                 @"session_type":self.sessionModel.session_type};
    //产生error数据时 判断是否有action
    NSDictionary *actionTag =command.baseActionData? @{@"action_id":command.baseActionData.action_id,
                                                       @"action_name":command.baseActionData.action_name,
                                                       @"action_type":command.baseActionData.action_type,
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actionTag];
    [tags addEntriesFromDictionary:command.tags];
    NSString *error = command.type == FTRUMDataViewLongTask?FT_TYPE_LONG_TASK :FT_TYPE_ERROR;
    
    [[FTMobileAgent sharedInstance] rumTrackES:error terminal:@"app" tags:tags fields:command.fields];
}
- (void)writeViewData{
    if (self.actionScope) {
        [self.actionScope writeActionData];
        self.actionScope = nil;
    }
    //判断冷启动 冷启动可能没有viewModel
    if (!self.viewModel) {
        return;
    }
    NSDictionary *tags = @{@"view_id":self.viewModel.view_id,
                           @"is_active":@(self.isActiveView),
                           @"view_referrer":self.viewModel.view_referrer,
                           @"view_name":self.viewModel.view_name,
                           @"session_id":self.sessionModel.session_id,
                           @"session_type":self.sessionModel.session_type,
    };
    NSDictionary *field = @{@"view_error_count":@(self.viewErrorCount),
                            @"view_resource_count":@(self.viewResourceCount),
                            @"view_long_task_count":@(self.viewLongTaskCount),
                            @"view_action_count":@(self.viewActionCount),
    };
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_VIEW terminal:@"app" tags:tags fields:field];
}

@end
