//
//  GuanceSDKCore.h
//  FTSDK
//
//  Created by hulilei on 2023/4/20.
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

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import "FTBaseInfoHandler.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import "FTRUMDependencies.h"
#import "FTLongTaskManager.h"
#import "NSDate+FTUtil.h"
#import "FTPresetProperty.h"
#import "FTRecordModel.h"
#import "FTLog.h"
#import "FTInnerLog.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceContentModel.h"
#import "FTSwizzle.h"
#import "FTSwizzler.h"
#import "FTSDKCompat.h"
#import "FTInternalConstants.h"
#import "FTRUMMonitor.h"
#import "FTRUMManager.h"
#import "FTHeatmap.h"
#import "FTRUMHandler.h"
#import "FTLongTaskDetector.h"
#import "FTCrash.h"
#import "FTLogger.h"
#import "FTLoggerDataWriteProtocol.h"
#import "FTLogger+Private.h"
#import "FTURLSessionInstrumentation.h"
#import "FTURLSessionDelegate.h"
#import "FTReadWriteHelper.h"
#import "FTJSONUtil.h"
#import "FTThreadDispatchManager.h"
#import "FTErrorDataProtocol.h"
#import "FTMessageReceiver.h"
#import "FTModuleManager.h"
#import "FTRumDatasProtocol.h"
#import "FTRumResourceProtocol.h"
#import "FTSRWebTrackingProtocol.h"
#import "FTTracerProtocol.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTExternalResourceProtocol.h"
#import "FTNetworkInfoManager.h"
#import "FTNetworkConnectivity.h"
#import "FTTrackDataManager.h"
#import "FTTrackerEventDBTool.h"
#if !TARGET_OS_TV
#import "FTWebViewJavascriptBridgeBase.h"
#import "FTWKWebViewHandler.h"
#import "FTWKWebViewHandler+Private.h"
#import "FTWKWebViewJavascriptBridge.h"
#endif
#import "FTDataWriterWorker.h"
#import "FTLoggerConfig.h"
#import "FTRequest.h"
#import "FTRequestBody.h"
#import "FTHTTPClient.h"
#import "FTRemoteConfigManager.h"
#import "FTRemoteConfigModel.h"
#import "FTRemoteConfigError.h"
#import "FTRemoteConfigTypeDefs.h"
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#endif
