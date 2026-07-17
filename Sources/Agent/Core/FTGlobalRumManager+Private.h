//
//  FTGlobalRumManager+Private.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/14.
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

#import "FTGlobalRumManager.h"

NS_ASSUME_NONNULL_BEGIN

@class FTRUMManager,FTRumConfig;
@protocol FTRUMDataWriteProtocol;

@interface FTGlobalRumManager (Private)
/// Object for handling RUM data
@property (nonatomic, strong) FTRUMManager *rumManager;

/// Set rum configuration options
/// - Parameter rumConfig: rum configuration options
- (void)setRumConfig:(FTRumConfig *)rumConfig writer:(id <FTRUMDataWriteProtocol>)writer;

- (void)updateSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate;

/// Shut down singleton
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
