//
//  FTSessionReplayCoreImports.h
//  SessionReplay
//
//  Created by hulilei on 2026/4/8.
//
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#pragma once

#import "Sources/Core/BaseUtils/include/FTBaseInfoHandler.h"
#import "Sources/Core/BaseUtils/include/FTConstants.h"
#import "Sources/Core/BaseUtils/include/FTDateUtil.h"
#import "Sources/Core/BaseUtils/include/FTInnerLog.h"
#import "Sources/Core/BaseUtils/include/FTJSONUtil.h"
#import "Sources/Core/BaseUtils/include/FTNetworkConnectivity.h"
#import "Sources/Core/BaseUtils/include/FTPresetProperty.h"
#import "Sources/Core/BaseUtils/include/FTReadWriteHelper.h"
#import "Sources/Core/BaseUtils/include/NSDate+FTUtil.h"
#import "Sources/Core/BaseUtils/include/FTSwizzler.h"
#import "Sources/Core/BaseUtils/Thread/include/FTThreadDispatchManager.h"
#import "Sources/Core/DataManager/FTTrackDataManager.h"
#import "Sources/Core/DataManager/Upload/FTHTTPClient.h"
#import "Sources/Core/DataManager/Upload/FTNetworkInfoManager.h"
#import "Sources/Core/DataManager/Upload/FTRequest.h"
#import "Sources/Core/DataManager/Upload/FTRequestBody.h"
#import "Sources/Core/FTRUM/Heatmap/FTHeatmap.h"
#import "Sources/Core/Public/FTWKWebViewHandler.h"
#import "Sources/Core/Protocol/FTMessageReceiver.h"
#import "Sources/Core/Protocol/FTModuleManager.h"
#import "Sources/Core/Protocol/FTSRWebTrackingProtocol.h"
#import "Sources/Core/RemoteConfig/FTRemoteConfigManager.h"
#import "Sources/Core/Public/FTRemoteConfigModel.h"

#endif
