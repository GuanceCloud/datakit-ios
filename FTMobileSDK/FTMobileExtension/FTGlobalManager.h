//
//  FTGlobal.h
//  FTMobileExtension
//
//  Created by hulilei on 2022/9/22.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import <Foundation/Foundation.h>
#import "URLSessionAutoInstrumentation.h"
#import "FTMobileConfig.h"
#import "FTTracerProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTGlobalManager : NSObject
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTTraceConfig *traceConfig;
@property (nonatomic, weak) URLSessionAutoInstrumentation *sessionInstrumentation;
@property (nonatomic, weak) id<FTTracerProtocol> tracer;
+ (instancetype)sharedInstance;

@end
NS_ASSUME_NONNULL_END
