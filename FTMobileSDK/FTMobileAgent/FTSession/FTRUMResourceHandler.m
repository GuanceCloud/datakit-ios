//
//  FTRUMResourceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMResourceHandler.h"
#import "FTRUMViewHandler.h"
#import "FTRUMDataModel.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTBaseInfoHander.h"
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) FTRUMResourceDataModel *model;
@property (nonatomic, weak) FTRUMViewHandler *parent;

@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model parent:(FTRUMViewHandler *)parent{
    self = [super init];
    if (self) {
        self.model = model;
        self.assistant = self;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data {
    if ([data isKindOfClass:FTRUMResourceDataModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if (newData.identifier == self.model.identifier) {
            switch (data.type) {
                case FTRUMDataResourceError:{
                    [self writeErrorData:data];
                    if (self.errorHandler) {
                        self.errorHandler();
                    }
                    return NO;
                }
                    break;
                case FTRUMDataResourceSuccess:{
                    [self writeResourceData:data];
                    if (self.resourceHandler) {
                        self.resourceHandler();
                    }
                    
                    return NO;
                }
                    break;
                default:
                    break;
            }
        }
    }

    return YES;
}
- (void)writeResourceData:(FTRUMDataModel *)data{
    NSDictionary *sessionTag = @{@"session_id":self.model.baseSessionData.session_id,
                                 @"session_type":self.model.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.model.baseViewData?@{@"view_id":self.model.baseViewData.view_id,
                                                        @"view_name":self.model.baseViewData.view_name,
                                                        @"view_referrer":self.model.baseViewData.view_referrer,
                                                        @"is_active":[FTBaseInfoHander boolStr:self.parent.isActiveView],
    }:@{};
    NSDictionary *actiontags =self.model.baseActionData? @{@"action_id":self.model.baseActionData.action_id,
                           @"action_name":self.model.baseActionData.action_name,
                           @"action_type":self.model.baseActionData.action_type
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_RESOURCE terminal:@"app" tags:tags fields:data.fields];

}
- (void)writeErrorData:(FTRUMDataModel *)data{
    NSDictionary *sessionTag = @{@"session_id":self.model.baseSessionData.session_id,
                                 @"session_type":self.model.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.model.baseViewData?@{@"view_id":self.model.baseViewData.view_id,
                                                        @"view_name":self.model.baseViewData.view_name,
                                                        @"view_referrer":self.model.baseViewData.view_referrer,
                                                        @"is_active":[FTBaseInfoHander boolStr:self.parent.isActiveView],
    }:@{};
    NSDictionary *actiontags =self.model.baseActionData? @{@"action_id":self.model.baseActionData.action_id,
                           @"action_name":self.model.baseActionData.action_name,
                           @"action_type":self.model.baseActionData.action_type
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_ERROR terminal:@"app" tags:tags fields:data.fields];
}
@end
