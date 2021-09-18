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
#import "FTDateUtil.h"
#import "FTBaseInfoHander.h"
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) FTRUMResourceDataModel *model;

@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model{
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
    NSDictionary *sessionTag = [self.model getGlobalSessionViewTags];
    NSDictionary *actiontags =self.model.baseActionData? [self.model.baseActionData getActionTags]:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_RESOURCE terminal:@"app" tags:tags fields:data.fields tm:[FTDateUtil dateTimeNanosecond:self.model.time]];
    

}
- (void)writeErrorData:(FTRUMDataModel *)data{
    NSDictionary *sessionViewTag = [data getGlobalSessionViewTags];
    
    NSDictionary *actiontags =self.model.baseActionData? [self.model.baseActionData getActionTags]:@{};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:actiontags];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_ERROR terminal:@"app" tags:tags fields:data.fields tm:[FTDateUtil dateTimeNanosecond:self.model.time]];
}
@end
