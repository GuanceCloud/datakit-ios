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
#import "FTConstants.h"

@implementation FTRUMDependencies
-(instancetype)copyWithZone:(NSZone *)zone {
    FTRUMDependencies *dependencies = [[[self class] allocWithZone:zone] init];
    dependencies.sampleRate = self.sampleRate;
    dependencies.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    dependencies.enableResourceHostIP = self.enableResourceHostIP;
    dependencies.appId = self.appId;
    dependencies.writer = self.writer;
    dependencies.errorMonitorInfoWrapper = self.errorMonitorInfoWrapper;
    dependencies.monitor = self.monitor;
    dependencies.fatalErrorContext = self.fatalErrorContext;
    dependencies.sessionHasReplay = self.sessionHasReplay;
    dependencies.sampledForErrorReplay = self.sampledForErrorReplay;
    dependencies.sessionReplaySampledFields = self.sessionReplaySampledFields;
    dependencies.sessionReplayStats = self.sessionReplayStats;
    return dependencies;
}
@end
