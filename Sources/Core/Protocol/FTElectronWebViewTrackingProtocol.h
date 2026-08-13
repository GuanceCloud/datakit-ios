//
//  FTElectronWebViewTrackingProtocol.h
//  FTSDK
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

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_OSX

NS_ASSUME_NONNULL_BEGIN

/// Runtime boundary between Session Replay and the optional Electron adapter.
///
/// Core owns this protocol so Session Replay can discover Electron support
/// without linking the Electron module directly.
@protocol FTElectronWebViewTrackingProtocol <NSObject>

/// Returns the optional recorder used to anchor an Electron slot in the native
/// AppKit view traversal. The concrete type lives in GuanceElectronWebView.
- (nullable id)sessionReplayRecorder;

/// Requests a full web replay snapshot from every visible registered renderer.
- (void)takeSubsequentFullSnapshot;

@end

NS_ASSUME_NONNULL_END

#endif
