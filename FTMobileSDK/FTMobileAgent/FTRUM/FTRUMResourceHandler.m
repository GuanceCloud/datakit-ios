//
//  FTRUMResourceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMResourceHandler.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) NSDate *time;
@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context{
    self = [super init];
    if (self) {
        self.identifier = model.identifier;
        self.assistant = self;
        self.time = model.time;
        self.context = [context copy];
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data {
    if ([data isKindOfClass:FTRUMResourceDataModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if ([newData.identifier isEqualToString:self.identifier]) {
            switch (data.type) {
                case FTRUMDataResourceError:{
                    [self writeErrorData:data];
                    return YES;
                }
                case FTRUMDataResourceSuccess:{
                    [self writeResourceData:data];
                    return YES;
                }
                case FTRUMDataResourceStop:{
                    if (self.resourceHandler) {
                        self.resourceHandler();
                    }
                    return NO;
                }
                default:
                    break;
            }
        }
    }

    return YES;
}
- (void)writeResourceData:(FTRUMDataModel *)data{
    FTRUMResourceDataModel *model = (FTRUMResourceDataModel *)data;
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields addEntriesFromDictionary:data.fields];
    [fields setValue:[FTDateUtil nanosecondTimeIntervalSinceDate:self.time toDate:data.time] forKey:@"duration"];
    if(model.metrics){
        [fields setValue:model.metrics.resource_ttfb forKey:@"resource_ttfb"];
        [fields setValue:model.metrics.resource_ssl forKey:@"resource_ssl"];
        [fields setValue:model.metrics.resource_tcp forKey:@"resource_tcp"];
        [fields setValue:model.metrics.resource_dns forKey:@"resource_dns"];
        [fields setValue:model.metrics.resource_first_byte forKey:@"resource_first_byte"];
        if ([model.metrics.duration intValue]>0) {
            [fields setValue:model.metrics.duration forKey:@"duration"];
        }
        [fields setValue:model.metrics.resource_trans forKey:@"resource_trans"];
    }
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_RESOURCE terminal:@"app" tags:tags fields:fields tm:[FTDateUtil dateTimeNanosecond:self.time]];
}
- (void)writeErrorData:(FTRUMDataModel *)data{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
        NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:data.tags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_ERROR terminal:@"app" tags:tags fields:data.fields tm:[FTDateUtil dateTimeNanosecond:self.time]];
}
@end
