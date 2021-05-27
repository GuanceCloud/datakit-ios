//
//  FTRUMSourceScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMResourceScope.h"
#import "FTRUMViewScope.h"
#import "FTRUMCommand.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
@interface FTRUMResourceScope()<FTRUMScopeProtocol>
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) FTRUMResourceCommand *command;
@property (nonatomic, weak) FTRUMViewScope *parent;

@end
@implementation FTRUMResourceScope
-(instancetype)initWithCommand:(FTRUMResourceCommand *)command parent:(FTRUMViewScope *)parent{
    self = [super init];
    if (self) {
        self.command = command;
        self.assistant = self;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMCommand *)command {
    if ([command isKindOfClass:FTRUMResourceCommand.class]) {
        FTRUMResourceCommand *newCommand = (FTRUMResourceCommand *)command;
        if (newCommand.identifier == self.command.identifier) {
            switch (command.type) {
                case FTRUMDataViewResourceError:{
                    [self writeErrorEvent:command];
                    if (self.errorHandler) {
                        self.errorHandler();
                    }
                    return NO;
                }
                    break;
                case FTRUMDataViewResourceSuccess:{
                    [self writeResourceEvent:command];
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
- (void)writeResourceEvent:(FTRUMCommand *)commamd{
    NSDictionary *sessionTag = @{@"session_id":self.command.baseSessionData.session_id,
                                 @"session_type":self.command.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.command.baseViewData?@{@"view_id":self.command.baseViewData.view_id,
                                                        @"view_name":self.command.baseViewData.view_name,
                                                        @"view_referrer":self.command.baseViewData.view_referrer,
                                                        @"is_active":@(self.parent.isActiveView),
    }:@{};
    NSDictionary *actiontags =self.command.baseActionData? @{@"action_id":self.command.baseActionData.action_id,
                           @"action_name":self.command.baseActionData.action_name,
                           @"action_type":self.command.baseActionData.action_type
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:commamd.tags];
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_RESOURCE terminal:@"app" tags:tags fields:commamd.fields];

}
- (void)writeErrorEvent:(FTRUMCommand *)command{
    NSDictionary *sessionTag = @{@"session_id":self.command.baseSessionData.session_id,
                                 @"session_type":self.command.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.command.baseViewData?@{@"view_id":self.command.baseViewData.view_id,
                                                        @"view_name":self.command.baseViewData.view_name,
                                                        @"view_referrer":self.command.baseViewData.view_referrer,
                                                        @"is_active":@(self.parent.isActiveView),
    }:@{};
    NSDictionary *actiontags =self.command.baseActionData? @{@"action_id":self.command.baseActionData.action_id,
                           @"action_name":self.command.baseActionData.action_name,
                           @"action_type":self.command.baseActionData.action_type
    }:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:command.tags];
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_ERROR terminal:@"app" tags:tags fields:command.fields];
}
@end
