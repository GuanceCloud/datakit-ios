//
//  FTRUMPlaceholderViewHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/15.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRUMPlaceholderViewHandler.h"
#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
#import "FTRUMResourceHandler.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog+Private.h"

@interface FTRUMPlaceholderViewHandler ()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) FTRUMActionHandler *actionHandler;
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;
@property (nonatomic, strong) FTMonitorItem *monitorItem;
@property (nonatomic, strong) NSMutableDictionary *viewProperty;//Stored in field
@end
@implementation FTRUMPlaceholderViewHandler
@synthesize context = _context;
-(instancetype)initWithModel:(FTRUMViewModel *)model context:(nonnull FTRUMContext *)context rumDependencies:(FTRUMDependencies *)rumDependencies{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.didReceiveStartData = NO;
        self.resourceHandlers = [NSMutableDictionary new];
        self.viewProperty = [NSMutableDictionary new];
        self.rumDependencies = rumDependencies;
        self.context = [context copy];
        if(model.fields && model.fields.allKeys.count>0){
            [self.viewProperty addEntriesFromDictionary:model.fields];
        }
    }
    return self;
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
   
    self.actionHandler =(FTRUMActionHandler *)[self.assistant manage:(FTRUMHandler *)self.actionHandler byPropagatingData:model context:context];
    switch (model.type) {
        case FTRUMDataViewStart:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                if (self.didReceiveStartData ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartData = YES;
            }else if(self.isActiveView == YES){
                self.isActiveView = NO;
            }
        }
            break;
        case FTRUMDataViewStop:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                self.isActiveView = NO;
                if(viewModel.fields && viewModel.fields.allKeys.count>0){
                    [self.viewProperty addEntriesFromDictionary:viewModel.fields];
                }
            }
        }
            break;
        case FTRUMDataStartAction:
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }else{
                FTInnerLogDebug(@"RUM Action %@ was dropped, because another action is still active for the same view.",((FTRUMActionModel *)model).action_name);
            }
            break;
        case FTRUMDataAddAction:
            [self addAction:model context:context];
            break;
        case FTRUMDataError:
            if (self.isActiveView) {
                FTRUMErrorData *error = (FTRUMErrorData *)model;
                if(error.fatal){
                    self.isActiveView = NO;
                }
                [self writeErrorData:model context:context];
            }
            break;
        case FTRUMDataResourceStart:
            if (self.isActiveView) {
                [self startResource:(FTRUMResourceDataModel *)model];
            }
            break;
        case FTRUMDataLongTask:
            if (self.isActiveView) {
                [self writeErrorData:model context:context];
            }
            break;
        default:
            break;
    }
    if ([model isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newModel = (FTRUMResourceDataModel *)model;
        FTRUMResourceHandler *handler =  self.resourceHandlers[newModel.identifier];
        self.resourceHandlers[newModel.identifier] =[handler.assistant manage:handler byPropagatingData:model context:context];
    }
    
    BOOL hasNoPendingResources = self.resourceHandlers.count == 0;
    BOOL shouldComplete = !self.isActiveView && hasNoPendingResources;
    if (shouldComplete) {
        [self.actionHandler writeActionData:[NSDate date] context:context];
    }
    return !shouldComplete;
}
- (void)startAction:(FTRUMDataModel *)model{
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    self.actionHandler = actionHandler;
}
- (void)addAction:(FTRUMDataModel *)model context:(NSDictionary *)context{
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    model.type = FTRUMDataStopAction;
    [actionHandler.assistant process:model context:context];
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc] initWithModel:model context:self.context dependencies:self.rumDependencies];
 
    self.resourceHandlers[model.identifier] =resourceHandler;
}
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields addEntriesFromDictionary:model.fields];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.rumDependencies.writer rumWrite:error tags:tags fields:fields time:model.tm];
}
@end
