//
//  FTLongTaskManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
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
#import "FTRUMDependencies.h"
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@class FTLongTaskEvent;
@protocol FTRunloopDetectorDelegate <NSObject>
/// Automatic collection passes one immutable incident snapshot.
- (void)longTaskDetected:(FTLongTaskEvent *)event;
- (void)anrStackDetected:(NSString *)slowStack appState:(NSString *)appState intervalAppState:(NSString *)intervalAppState time:(long long)time;
@end
@interface FTLongTaskManager : NSObject
-(instancetype)initWithDependencies:(FTRUMDependencies *)dependencies
                           delegate:(id<FTRunloopDetectorDelegate>)delegate
                 backtraceReporting:(id<FTBacktraceReporting>)backtraceReporting
                  enableTrackAppANR:(BOOL)enableANR
               enableTrackAppFreeze:(BOOL)enableFreeze
                   freezeDurationMs:(long)freezeThreshold;

-(void)shutDown;
@end

NS_ASSUME_NONNULL_END
