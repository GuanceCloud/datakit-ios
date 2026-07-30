//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#ifndef FTSDK_h
#define FTSDK_h
#import <TargetConditionals.h>
#import "FTSDKConfig.h"
#import "FTMobileConfig.h"
#import "FTExternalDataManager.h"
#import "FTGlobalRumManager.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceContentModel.h"
#import "FTURLSessionDelegate.h"
#import "FTURLSessionInterceptor.h"
#import "FTTraceManager.h"
#import "FTLogger.h"
#import "FTSDKAgent.h"
#import "FTMobileAgent.h"
#import "FTRumDatasProtocol.h"
#import "FTLog.h"
#import "FTTraceContext.h"
#import "FTLoggerConfig.h"
#import "FTRumConfig.h"
#import "FTConstants.h"
#if !TARGET_OS_TV
#import "FTWKWebViewHandler.h"
#endif
#import "FTSDKConfig+Private.h"
#import "FTMobileConfig+Private.h"
#import "FTActionTrackingHandler.h"
#import "FTViewTrackingHandler.h"
#import "FTRUMView.h"
#import "FTRUMAction.h"
#import "FTDefaultActionTrackingHandler.h"
#import "FTDefaultUIKitViewTrackingHandler.h"

#endif /* FTSDK_h */
