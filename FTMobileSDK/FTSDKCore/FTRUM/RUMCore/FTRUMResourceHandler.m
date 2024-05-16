//
//  FTRUMResourceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMResourceHandler.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) NSDate *time;
@property (nonatomic, strong) NSMutableDictionary *resourceProperty;
@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context dependencies:(nonnull FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.dependencies = dependencies;
        self.identifier = model.identifier;
        self.assistant = self;
        self.time = model.time;
        self.resourceProperty = [[NSMutableDictionary alloc]init];
        if(model.fields && model.fields.allKeys.count>0){
            [self.resourceProperty addEntriesFromDictionary:model.fields];
        }
        self.context = context;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data {
    if ([data isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if ([newData.identifier isEqualToString:self.identifier]) {
            switch (data.type) {
                case FTRUMDataResourceComplete:
                    if (self.resourceHandler) {
                        self.resourceHandler();
                    }
                    [self writeResourceData:data];
                    return NO;
                case FTRUMDataResourceStop:{
                    if(data.fields && data.fields.allKeys.count>0){
                        [self.resourceProperty addEntriesFromDictionary:data.fields];
                    }
                }
                    break;
                case FTRUMDataResourceError:{
                    if(self.errorHandler){
                        self.errorHandler();
                    }
                    [self writeResourceError:data];
                }
                    break;
                default:
                    break;
            }
        }
    }

    return YES;
}
- (void)writeResourceError:(FTRUMDataModel *)model{
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:model.tags];
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_ERROR tags:tags fields:model.fields time:model.tm];
}
- (void)writeResourceData:(FTRUMDataModel *)data{
    FTRUMResourceDataModel *model = (FTRUMResourceDataModel *)data;
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if(self.resourceProperty && self.resourceProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.resourceProperty];
    }
    [fields addEntriesFromDictionary:data.fields];
    [fields setValue:[self.time ft_nanosecondTimeIntervalToDate:data.time] forKey:FT_DURATION];
    if(model.metrics){
        [fields setValue:model.metrics.resource_ttfb forKey:FT_KEY_RESOURCE_TTFB];
        [fields setValue:model.metrics.resource_ssl forKey:FT_KEY_RESOURCE_SSL];
        [fields setValue:model.metrics.resource_tcp forKey:FT_KEY_RESOURCE_TCP];
        [fields setValue:model.metrics.resource_dns forKey:FT_KEY_RESOURCE_DNS];
        [fields setValue:model.metrics.resource_first_byte forKey:FT_KEY_RESOURCE_FIRST_BYTE];
        if ([model.metrics.duration longLongValue]>0) {
            [fields setValue:model.metrics.duration forKey:FT_DURATION];
        }
        [fields setValue:model.metrics.resource_trans forKey:FT_KEY_RESOURCE_TRANS];
    }
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_RESOURCE tags:tags fields:fields time:[self.time ft_nanosecondTimeStamp]];
}
@end
