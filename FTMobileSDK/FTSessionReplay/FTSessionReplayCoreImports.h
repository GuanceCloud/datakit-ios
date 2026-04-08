//
//  FTSessionReplayCoreImports.h
//  FTSessionReplay
//
//  Created by Codex on 2026/4/8.
//

#pragma once

#if defined(SWIFT_PACKAGE)
@import FTSDKCore;
#else
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTBaseInfoHandler.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTConstants.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTDateUtil.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTInnerLog.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTJSONUtil.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTNetworkConnectivity.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTPresetProperty.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/FTReadWriteHelper.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Base/NSDate+FTUtil.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Swizzle/FTSwizzler.h"
#import "FTMobileSDK/FTSDKCore/BaseUtils/Thread/include/FTThreadDispatchManager.h"
#import "FTMobileSDK/FTSDKCore/DataManager/FTTrackDataManager.h"
#import "FTMobileSDK/FTSDKCore/DataManager/Upload/FTHTTPClient.h"
#import "FTMobileSDK/FTSDKCore/DataManager/Upload/FTNetworkInfoManager.h"
#import "FTMobileSDK/FTSDKCore/DataManager/Upload/FTRequest.h"
#import "FTMobileSDK/FTSDKCore/DataManager/Upload/FTRequestBody.h"
#import "FTMobileSDK/FTSDKCore/FTWKWebView/FTWKWebViewHandler.h"
#import "FTMobileSDK/FTSDKCore/Protocol/FTMessageReceiver.h"
#import "FTMobileSDK/FTSDKCore/Protocol/FTModuleManager.h"
#import "FTMobileSDK/FTSDKCore/Protocol/FTSRWebTrackingProtocol.h"
#import "FTMobileSDK/FTSDKCore/RemoteConfig/FTRemoteConfigManager.h"
#import "FTMobileSDK/FTSDKCore/RemoteConfig/FTRemoteConfigModel.h"
#endif
