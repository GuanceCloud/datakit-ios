//
//  FTLogger+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTLogger.h"
#import "FTLoggerDataWriteProtocol.h"
#import "FTLinkRumDataProvider.h"

NS_ASSUME_NONNULL_BEGIN
@class FTLoggerConfig;

@interface FTLogger ()

@property (nonatomic, weak, nullable) id<FTLinkRumDataProvider> linkRumDataProvider;
/// Called when SDK starts, enables Logger
/// - Parameters:
///   - enable: Whether to output to console
///   - enableCustomLog: Whether to collect custom logs
///   - filter: Log filtering rules
///   - sampletRate: Collection rate
///   - writer: Data write object
- (void)startWithLoggerConfig:(FTLoggerConfig *)config writer:(id<FTLoggerDataWriteProtocol>)writer;


/// Synchronously execute log processing queue
- (void)syncProcess;

/// Update dynamically configured settings obtained remotely
-(void)updateLoggerConfiguration:(FTLoggerConfig *)configuration;
@end

NS_ASSUME_NONNULL_END
