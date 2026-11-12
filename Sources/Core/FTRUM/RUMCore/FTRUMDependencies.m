//
//  FTRUMDependencies.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/10.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTRUMDependencies.h"
#import "FTRUMViewTimingPredicates.h"
#import "FTIssueFieldEnricher.h"
#import "FTVisitorIDManager.h"

@interface FTRUMDependencies ()
@property (nonatomic, strong, nullable, readwrite) FTIssueFieldEnricher *issueFieldEnricher;
@end

@implementation FTRUMDependencies
- (instancetype)init {
    if ((self = [super init])) {
        _nextViewActionPredicate = [FTRUMTimeBasedNextViewActionPredicate new];
        _networkSettledResourcePredicate = [FTRUMTimeBasedNetworkSettledPredicate new];
    }
    return self;
}


- (FTRUMWriteData *)newNativeWriteDataWithSource:(NSString *)source tags:(NSDictionary *)tags
                                        fields:(NSDictionary *)fields context:(FTRUMPropertySnapshot *)context
                                 customTagKeys:(NSSet<NSString *> *)tagKeys customFieldKeys:(NSSet<NSString *> *)fieldKeys
                                          time:(long long)time {
    NSString *visitorID = [FTVisitorIDManager sharedInstance].snapshot.value;
    FTRUMWriteData *data = [[FTRUMWriteData alloc] initWithSource:source tags:tags fields:fields
        context:context customTagKeys:tagKeys customFieldKeys:fieldKeys time:time];
    data.visitorIDSnapshot = visitorID;
    return data;
}

- (void)setIssueDataProvider:(nullable FTIssueDataProvider)issueDataProvider {
    _issueDataProvider = [issueDataProvider copy];
    self.issueFieldEnricher = _issueDataProvider
        ? [[FTIssueFieldEnricher alloc] initWithProvider:_issueDataProvider]
        : nil;
}

-(instancetype)copyWithZone:(NSZone *)zone {
    FTRUMDependencies *dependencies = [[[self class] allocWithZone:zone] init];
    dependencies.sampleRate = self.sampleRate;
    dependencies.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    dependencies.enableResourceHostIP = self.enableResourceHostIP;
    dependencies.enableTraceUserAction = self.enableTraceUserAction;
    dependencies.ignoreBackgroundLongTaskAndANR = self.ignoreBackgroundLongTaskAndANR;
    dependencies.appId = self.appId;
    dependencies.writer = self.writer;
    dependencies.networkSettledResourcePredicate = self.networkSettledResourcePredicate;
    dependencies.nextViewActionPredicate = self.nextViewActionPredicate;
    dependencies.errorMonitorInfoWrapper = self.errorMonitorInfoWrapper;
    dependencies.monitor = self.monitor;
    dependencies.fatalErrorContext = self.fatalErrorContext;
    dependencies.issueDataProvider = self.issueDataProvider;
    dependencies.sessionHasReplay = self.sessionHasReplay;
    dependencies.sampledForErrorReplay = self.sampledForErrorReplay;
    dependencies.sessionReplaySampledFields = self.sessionReplaySampledFields;
    dependencies.sessionReplayStats = self.sessionReplayStats;
    dependencies.appStateHistory = self.appStateHistory;
    return dependencies;
}
@end
