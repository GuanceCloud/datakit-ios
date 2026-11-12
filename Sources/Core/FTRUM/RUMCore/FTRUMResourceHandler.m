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
#import "FTRUMNetworkSettledMetric.h"

// A single normalized interval serves both Resource output and TNS.
typedef struct {
    long long startNs;
    long long endNs;
    BOOL valid;
} FTRUMResourceTiming;
@interface FTRUMResourceHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, strong, nullable) FTRUMNetworkSettledMetric *networkMetric;
@property (nonatomic, copy,readwrite) NSString *identifier;
@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) long long startNs;
@property (nonatomic, strong, nullable) NSNumber *stopNs;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, strong, nullable) NSDate *resourceStopTime;
@property (nonatomic, strong) NSMutableDictionary *resourceProperty;
@property (nonatomic, strong) NSMutableSet<NSString *> *resourceCustomKeys;
@property (nonatomic, strong, nullable) NSNumber *networkAvailable;
@property (nonatomic, strong, nullable) NSNumber *networkSignalStrength;

@property (nonatomic, copy, nullable) NSString *visitorIDSnapshot;
- (FTRUMPropertySnapshot *)context:(FTRUMPropertySnapshot *)context byApplyingVisitorID:(NSString *)visitorID;
@end
@implementation FTRUMResourceHandler
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context dependencies:(nonnull FTRUMDependencies *)dependencies networkMetric:(FTRUMNetworkSettledMetric *)networkMetric{
    self = [super init];
    if (self) {
        self.dependencies = dependencies;
        self.identifier = model.identifier;
        self.assistant = self;
        self.time = model.time;
        self.startNs = model.tm;
        self.networkMetric = networkMetric;
        [networkMetric startResourceWithKey:model.identifier startNs:model.tm URL:model.tags[FT_KEY_RESOURCE_URL]];
        self.visitorIDSnapshot = model.visitorIDSnapshot;
        self.resourceCustomKeys = [NSMutableSet set];
        self.resourceProperty = [[NSMutableDictionary alloc]init];
        if(model.fields && model.fields.allKeys.count>0){
            FTRUMMergeProperties(self.resourceProperty, self.resourceCustomKeys, model.fields, model.customFieldKeys);
        }
        self.networkAvailable = model.networkAvailable;
        self.networkSignalStrength = model.networkSignalStrength;
        self.context = context;
    }
    return self;
}

- (BOOL)process:(nonnull FTRUMDataModel *)data context:(nonnull FTRUMPropertySnapshot *)context{
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
                        FTRUMMergeProperties(self.resourceProperty, self.resourceCustomKeys, fields, data.customFieldKeys);
                    }
                }
                    break;
                case FTRUMDataResourceStart:
                    if (data.fields) FTRUMMergeProperties(self.resourceProperty, self.resourceCustomKeys, data.fields, data.customFieldKeys);
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
                    [self.networkMetric dropResourceWithKey:self.identifier];
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
- (void)writeResourceError:(FTRUMDataModel *)model context:(FTRUMPropertySnapshot *)context{
    NSMutableSet *customKeys = [NSMutableSet set];
    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:self.dependencies.sessionHasReplay forKey:FT_SESSION_HAS_REPLAY];
    FTRUMMergeProperties(fields, customKeys, model.fields, model.customFieldKeys);
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields ?: @{}];
    if (self.visitorIDSnapshot.length > 0) {
        [tags removeObjectForKey:FT_VISITOR_ID];
        [fields setValue:nil forKey:FT_VISITOR_ID];
        context = [self context:context byApplyingVisitorID:self.visitorIDSnapshot];
    }
    FTRUMWriteData *writeData = [[FTRUMWriteData alloc] initWithSource:FT_RUM_SOURCE_ERROR tags:tags fields:fields
        context:context customTagKeys:[NSSet set] customFieldKeys:customKeys time:model.tm];
    FTRUMWrite(self.dependencies.writer, writeData);
}
- (FTRUMResourceTiming)timingForModel:(FTRUMResourceDataModel *)model {
    long long startNs = model.metrics.fetchStartNsTimeInterval;
    long long endNs = model.metrics.fetchEndNsTimeInterval;
    if (startNs > 0 && endNs >= startNs) return (FTRUMResourceTiming){startNs, endNs, YES};
    startNs = self.startNs;
    endNs = self.stopNs.longLongValue;
    return (FTRUMResourceTiming){startNs, endNs, startNs > 0 && self.stopNs && endNs >= startNs};
}
- (void)writeResourceData:(FTRUMDataModel *)data context:(FTRUMPropertySnapshot *)context{
    NSMutableSet *customKeys = [NSMutableSet set];
    FTRUMResourceDataModel *model = (FTRUMResourceDataModel *)data;
    FTRUMResourceTiming timing = [self timingForModel:model];
    long long resourceStartTime = timing.startNs;
    // Keep the original URL before any writer modifier or filter can transform it.
    [self.networkMetric updateResourceWithKey:self.identifier startNs:timing.startNs URL:model.tags[FT_KEY_RESOURCE_URL]];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if(self.resourceProperty && self.resourceProperty.allKeys.count>0){
        FTRUMMergeProperties(fields, customKeys, self.resourceProperty, self.resourceCustomKeys);
    }
    FTRUMMergeProperties(fields, customKeys, data.fields, data.customFieldKeys);
    [fields setValue:self.dependencies.sessionHasReplay forKey:FT_SESSION_HAS_REPLAY];

    NSDate *fallbackEnd = self.resourceStopTime ?: data.time;
    // Legacy duration-only metrics remain event-only when no interval can be established.
    NSNumber *duration = timing.valid ? @(timing.endNs - timing.startNs)
        : (model.metrics.fetchInterval ?: [self.time ft_nanosecondTimeIntervalToDate:fallbackEnd]);
    [fields setValue:duration forKey:FT_DURATION];
    if(model.metrics){
        [fields setValue:model.metrics.ttfb forKey:FT_KEY_RESOURCE_TTFB];
        [fields setValue:model.metrics.ssl forKey:FT_KEY_RESOURCE_SSL];
        [fields setValue:model.metrics.tcp forKey:FT_KEY_RESOURCE_TCP];
        [fields setValue:model.metrics.dns forKey:FT_KEY_RESOURCE_DNS];
        [fields setValue:model.metrics.firstByte forKey:FT_KEY_RESOURCE_FIRST_BYTE];
        [fields setValue:model.metrics.trans forKey:FT_KEY_RESOURCE_TRANS];
        [fields setValue:model.metrics.resource_dns_time forKey:FT_KEY_RESOURCE_DNS_TIME];
        [fields setValue:model.metrics.resource_ssl_time forKey:FT_KEY_RESOURCE_SSL_TIME];
        [fields setValue:model.metrics.resource_download_time forKey:FT_KEY_RESOURCE_DOWNLOAD_TIME];
        [fields setValue:model.metrics.resource_first_byte_time forKey:FT_KEY_RESOURCE_FIRST_BYTE_TIME];
        [fields setValue:model.metrics.resource_redirect_time forKey:FT_KEY_RESOURCE_REDIRECT_TIME];
        [fields setValue:model.metrics.resource_connect_time forKey:FT_KEY_RESOURCE_CONNECT_TIME];
    }
    [fields setValue:[self.dependencies.appStateHistory stateFrom:resourceStartTime
                                                               duration:[fields[FT_DURATION] longLongValue]] forKey:@"app_state"];
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields ?: @{}];
    // The first Start owns both network facts, including absent measurements.
    [fields setValue:self.networkAvailable forKey:FT_KEY_NETWORK_AVAILABLE];
    [fields setValue:self.networkSignalStrength forKey:FT_KEY_NETWORK_SIGNAL_STRENGTH];

    NSDictionary *sessionTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:sessionTag];
    [tags addEntriesFromDictionary:data.tags];
    [tags setValue:model.identifier forKey:FT_KEY_RESOURCE_ID];
    if (self.visitorIDSnapshot.length > 0) {
        [tags removeObjectForKey:FT_VISITOR_ID];
        [fields setValue:nil forKey:FT_VISITOR_ID];
        context = [self context:context byApplyingVisitorID:self.visitorIDSnapshot];
    }
    FTRUMWriteData *writeData = [[FTRUMWriteData alloc] initWithSource:FT_RUM_SOURCE_RESOURCE tags:tags fields:fields
        context:context customTagKeys:[NSSet set] customFieldKeys:customKeys time:resourceStartTime];
    BOOL accepted = FTRUMWrite(self.dependencies.writer, writeData);
    if (accepted && timing.valid) {
        [self.networkMetric completeResourceWithKey:self.identifier endNs:timing.endNs];
    } else {
        [self.networkMetric dropResourceWithKey:self.identifier];
    }
}
- (FTRUMPropertySnapshot *)context:(FTRUMPropertySnapshot *)context byApplyingVisitorID:(NSString *)visitorID{
    return [context snapshotBySettingSystemValue:visitorID forKey:FT_VISITOR_ID];
}
@end
