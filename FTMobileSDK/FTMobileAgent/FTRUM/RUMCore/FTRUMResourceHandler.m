//
//  FTRUMResourceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMResourceHandler.h"
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
        self.context = context;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data {
    if ([data isKindOfClass:FTRUMResourceDataModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if ([newData.identifier isEqualToString:self.identifier]) {
            switch (data.type) {
                case FTRUMDataResourceComplete:{
                    [self writeResourceData:data];
                    return NO;
                }
                case FTRUMDataResourceStop:{
                    if (self.resourceHandler) {
                        self.resourceHandler();
                    }
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
    [fields setValue:[FTDateUtil nanosecondTimeIntervalSinceDate:self.time toDate:data.time] forKey:FT_DURATION];
    if(model.metrics){
        [fields setValue:model.metrics.resource_ttfb forKey:FT_RUM_KEY_RESOURCE_TTFB];
        [fields setValue:model.metrics.resource_ssl forKey:FT_RUM_KEY_RESOURCE_SSL];
        [fields setValue:model.metrics.resource_tcp forKey:FT_RUM_KEY_RESOURCE_TCP];
        [fields setValue:model.metrics.resource_dns forKey:FT_RUM_KEY_RESOURCE_DNS];
        [fields setValue:model.metrics.resource_first_byte forKey:FT_RUM_KEY_RESOURCE_FIRST_BYTE];
        if ([model.metrics.duration intValue]>0) {
            [fields setValue:model.metrics.duration forKey:FT_DURATION];
        }
        [fields setValue:model.metrics.resource_trans forKey:FT_RUM_KEY_RESOURCE_TRANS];
    }
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [self.context.writer rumWrite:FT_MEASUREMENT_RUM_RESOURCE terminal:FT_TERMINAL_APP tags:tags fields:fields tm:[FTDateUtil dateTimeNanosecond:self.time]];
}
@end
