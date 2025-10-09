//
//  FTRUMDependencies.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTRUMDependencies.h"
#import "FTConstants.h"

@implementation FTRUMDependencies
-(instancetype)copyWithZone:(NSZone *)zone {
    FTRUMDependencies *dependencies = [[[self class] allocWithZone:zone] init];
    dependencies.sampleRate = self.sampleRate;
    dependencies.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    dependencies.enableResourceHostIP = self.enableResourceHostIP;
    dependencies.appId = self.appId;
    dependencies.writer = self.writer;
    dependencies.errorMonitorType = self.errorMonitorType;
    dependencies.monitor = self.monitor;
    dependencies.fatalErrorContext = self.fatalErrorContext;
    dependencies.currentSessionSample = self.currentSessionSample;
    dependencies.sessionHasReplay = self.sessionHasReplay;
    dependencies.sampledForErrorReplay = self.sampledForErrorReplay;
    dependencies.sampledForErrorSession = self.sampledForErrorSession;
    dependencies.sessionReplaySampledFields = self.sessionReplaySampledFields;
    dependencies.sessionReplayStats = self.sessionReplayStats;
    return dependencies;
}
@end
