//
//  FTRUMResourceHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTRUMResourceHandler.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTRUMContext.h"
#import "FTModuleManager.h"
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) long long startNs;
@property (nonatomic, strong, nullable) NSNumber *stopNs;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, strong, nullable) NSDate *resourceStopTime;
@property (nonatomic, strong) NSMutableDictionary *resourceProperty;
@property (nonatomic, strong) NSNumber *networkAvailable;
@property (nonatomic, copy, nullable) NSString *visitorIDSnapshot;
- (NSDictionary *)context:(NSDictionary *)context byApplyingVisitorID:(NSString *)visitorID;
@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context dependencies:(nonnull FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.dependencies = dependencies;
        self.identifier = model.identifier;
        self.assistant = self;
        self.time = model.time;
        self.startNs = model.tm;
        self.visitorIDSnapshot = model.visitorIDSnapshot;
        self.resourceProperty = [[NSMutableDictionary alloc]init];
        if(model.fields && model.fields.allKeys.count>0){
            [self.resourceProperty addEntriesFromDictionary:model.fields];
        }
        if ([model.fields[FT_KEY_NETWORK_AVAILABLE] isKindOfClass:NSNumber.class]) {
            self.networkAvailable = model.fields[FT_KEY_NETWORK_AVAILABLE];
        }
        self.context = context;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data context:(nonnull NSDictionary *)context{
    if (self.completed) return NO;
    if ([data isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newData = (FTRUMResourceDataModel *)data;
        if ([newData.identifier isEqualToString:self.identifier]) {
            switch (data.type) {
                case FTRUMDataResourceComplete:
                    self.completed = YES;
                    if (self.resourceHandler) {
                        self.resourceHandler(YES);
                    }
                    [self writeResourceData:data context:context];
                    return NO;
                case FTRUMDataResourceStop:{
                    if (self.stopNs) break;
                    self.resourceStopTime = data.time;
                    self.stopNs = @(data.tm);
                    if(data.fields && data.fields.allKeys.count>0){
                        NSMutableDictionary *fields = [data.fields mutableCopy];
                        if (self.visitorIDSnapshot.length > 0) {
                            [fields removeObjectForKey:FT_VISITOR_ID];
                        }
                        [self.resourceProperty addEntriesFromDictionary:fields];
                    }
                }
                    break;
                case FTRUMDataResourceStart:
                    if (data.fields) [self.resourceProperty addEntriesFromDictionary:data.fields];
                    break;
                case FTRUMDataResourceError:{
                    if(self.errorHandler){
                        self.errorHandler();
                    }
                    [self writeResourceError:data context:context];
                }
                    break;
                case FTRUMDataResourceAbandon:
                    self.completed = YES;
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
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:self.dependencies.sessionHasReplay forKey:FT_SESSION_HAS_REPLAY];
    [fields addEntriesFromDictionary:model.fields];
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields];
    if (self.visitorIDSnapshot.length > 0) {
        [tags removeObjectForKey:FT_VISITOR_ID];
        [fields removeObjectForKey:FT_VISITOR_ID];
        context = [self context:context byApplyingVisitorID:self.visitorIDSnapshot];
    }
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_ERROR tags:tags fields:fields dynamicContext:context time:model.tm];
}
- (void)writeResourceData:(FTRUMDataModel *)data context:(NSDictionary *)context{
    FTRUMResourceDataModel *model = (FTRUMResourceDataModel *)data;
    long long resourceStartTime = model.metrics.fetchStartNsTimeInterval;
    if (resourceStartTime <= 0) {
        resourceStartTime = [self.time ft_nanosecondTimeStamp];
    }
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if(self.resourceProperty && self.resourceProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.resourceProperty];
    }
    [fields addEntriesFromDictionary:data.fields];
    [fields setValue:self.networkAvailable forKey:FT_KEY_NETWORK_AVAILABLE];
    [fields setValue:self.dependencies.sessionHasReplay forKey:FT_SESSION_HAS_REPLAY];
    NSDate *fallbackEnd = self.resourceStopTime ?: data.time;
    [fields setValue:[self.time ft_nanosecondTimeIntervalToDate:fallbackEnd] forKey:FT_DURATION];
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
    }
    fields[@"app_state"] = [self.dependencies.appStateHistory stateFrom:resourceStartTime
                                                               duration:[fields[FT_DURATION] longLongValue]];
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields];
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [tags setValue:model.identifier forKey:FT_KEY_RESOURCE_ID];
    if (self.visitorIDSnapshot.length > 0) {
        [tags removeObjectForKey:FT_VISITOR_ID];
        [fields removeObjectForKey:FT_VISITOR_ID];
        context = [self context:context byApplyingVisitorID:self.visitorIDSnapshot];
    }
    BOOL accepted = FTRUMWriteAccepted(self.dependencies.writer, FT_RUM_SOURCE_RESOURCE, tags, fields, context, resourceStartTime);
    if (accepted && self.metricHandler) {
        long long startNs = model.metrics.fetchStartNsTimeInterval;
        long long endNs = model.metrics.fetchEndNsTimeInterval;
        if (startNs <= 0 || endNs < startNs) {
            startNs = self.startNs;
            endNs = self.stopNs ? self.stopNs.longLongValue : 0;
        }
        if (endNs >= startNs && startNs > 0) self.metricHandler(startNs, endNs);
    }
}
- (NSDictionary *)context:(NSDictionary *)context byApplyingVisitorID:(NSString *)visitorID{
    NSMutableDictionary *managedContext = [context mutableCopy] ?: [NSMutableDictionary dictionary];
    managedContext[FT_VISITOR_ID] = visitorID;
    return [managedContext copy];
}
@end
