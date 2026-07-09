//
//  FTRUMDependencies.h
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

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
#import "FTInternalConstants.h"
#import "FTRUMMonitor.h"
#import "FTFatalErrorContext.h"
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRUMDependencies : NSObject
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sessionOnErrorSampleRate;
@property (nonatomic, assign) BOOL enableResourceHostIP;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, weak, nullable) id<FTRUMDataWriteProtocol> writer;
@property (nonatomic, strong) id<FTErrorMonitorInfoWrapper> errorMonitorInfoWrapper;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong, nullable) FTFatalErrorContext *fatalErrorContext;
@property (atomic, strong) NSDictionary *linkRUMSessionContext;
@property (atomic, strong, nullable) NSDictionary *lastViewUserCustomDatas;

//The following properties need to be readwrite in rumQueue
@property (nonatomic, strong) NSNumber *sessionHasReplay;
@property (nonatomic, assign) BOOL sampledForErrorReplay;
@property (nonatomic, strong) NSDictionary *sessionReplaySampledFields;
@property (nonatomic, strong) NSDictionary *sessionReplayStats;

@end

NS_ASSUME_NONNULL_END
