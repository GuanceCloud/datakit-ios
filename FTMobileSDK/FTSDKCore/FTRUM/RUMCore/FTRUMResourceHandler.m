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
#import "FTResourceMetricsModel+Private.h"
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

- (BOOL)process:(nonnull FTRUMDataModel *)data context:(nonnull NSDictionary *)context{
    if ([data isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if ([newData.identifier isEqualToString:self.identifier]) {
            switch (data.type) {
                case FTRUMDataResourceComplete:
                    if (self.resourceHandler) {
                        self.resourceHandler(YES);
                    }
                    [self writeResourceData:data context:context];
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
                    [self writeResourceError:data context:context];
                }
                    break;
                case FTRUMDataResourceAbandon:
                    if (self.resourceHandler) {
                        self.resourceHandler(NO);
                    }
                    return NO;
                default:
                    break;
            }
        }
    }

    return YES;
}
- (void)writeResourceError:(FTRUMDataModel *)model context:(NSDictionary *)context{
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields addEntriesFromDictionary:model.fields];
    [fields addEntriesFromDictionary:self.dependencies.sampleFieldsDict];
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_ERROR tags:tags fields:fields time:model.tm];
}
- (void)writeResourceData:(FTRUMDataModel *)data context:(NSDictionary *)context{
    FTRUMResourceDataModel *model = (FTRUMResourceDataModel *)data;
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if(self.resourceProperty && self.resourceProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.resourceProperty];
    }
    [fields addEntriesFromDictionary:data.fields];
    [fields addEntriesFromDictionary:self.dependencies.sampleFieldsDict];
    if(model.metrics){
        [fields setValue:model.metrics.ttfb forKey:FT_KEY_RESOURCE_TTFB];
        [fields setValue:model.metrics.ssl forKey:FT_KEY_RESOURCE_SSL];
        [fields setValue:model.metrics.tcp forKey:FT_KEY_RESOURCE_TCP];
        [fields setValue:model.metrics.dns forKey:FT_KEY_RESOURCE_DNS];
        [fields setValue:model.metrics.firstByte forKey:FT_KEY_RESOURCE_FIRST_BYTE];
        [fields setValue:model.metrics.fetchInterval forKey:FT_DURATION];
        [fields setValue:model.metrics.trans forKey:FT_KEY_RESOURCE_TRANS];
        [fields setValue:model.metrics.resource_dns_time forKey:FT_KEY_RESOURCE_DNS_TIME];
        [fields setValue:model.metrics.resource_ssl_time forKey:FT_KEY_RESOURCE_SSL_TIME];
        [fields setValue:model.metrics.resource_download_time forKey:FT_KEY_RESOURCE_DOWNLOAD_TIME];
        [fields setValue:model.metrics.resource_first_byte_time forKey:FT_KEY_RESOURCE_FIRST_BYTE_TIME];
        [fields setValue:model.metrics.resource_redirect_time forKey:FT_KEY_RESOURCE_REDIRECT_TIME];
        [fields setValue:model.metrics.resource_connect_time forKey:FT_KEY_RESOURCE_CONNECT_TIME];
    }else{
        [fields setValue:[self.time ft_nanosecondTimeIntervalToDate:data.time] forKey:FT_DURATION];
    }
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_RESOURCE tags:tags fields:fields time:[self.time ft_nanosecondTimeStamp]];
}
@end
