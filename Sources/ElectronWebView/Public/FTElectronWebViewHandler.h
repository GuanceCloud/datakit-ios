//
//  FTElectronWebViewHandler.h
//  GuanceElectronWebView
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
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FTElectronWebViewCommandHandler)(
    int64_t webContentsID,
    NSString *command
);

FOUNDATION_EXPORT NSString *const
    FTElectronWebViewCommandTakeSubsequentFullSnapshot;

/// Bridges Electron WebContents RUM and Session Replay messages into the native
/// Guance SDK.
///
/// Electron Main must explicitly register every container before forwarding
/// messages. The renderer-provided payload never selects its own replay slot.
@interface FTElectronWebViewHandler : NSObject

+ (instancetype)sharedInstance;

/// Activates the optional Electron recorder provider.
///
/// Call this after Native RUM has an active View and before starting Native
/// Session Replay. Applications do not create `FTElectronWebViewRecorder`
/// directly.
- (void)start;

/// Bridge integration entry point. Activates the recorder provider and installs
/// the allowlisted native-to-Electron command callback.
///
/// Normal native application initialization should call `start` instead. This
/// overload is intended for the Node bridge that routes commands to a trusted
/// Electron WebContents.
- (void)startWithCommandHandler:
    (nullable FTElectronWebViewCommandHandler)commandHandler;

/// Registers a WebContents and its logical layout within a Native container.
///
/// `hostView` must be the smallest Native container-controller root that
/// contains this WebContentsViewCocoa. A BrowserWindow content view is valid
/// only when it contains one visible Chromium view. For a Native controller
/// switch inside one NSWindow, pass each controller's own container root.
/// Call this on the main thread because `hostView` is an AppKit object.
///
/// `bounds` and `zIndex` are trusted Electron layout metadata used only as a
/// fallback when the same Native container deliberately displays more than one
/// Chromium view. They are not used to match views across containers.
- (BOOL)registerWebContentsID:(int64_t)webContentsID
                       slotID:(int64_t)slotID
                     hostView:(NSView *)hostView
                       bounds:(CGRect)bounds
                      visible:(BOOL)visible
                       zIndex:(NSInteger)zIndex;

/// Updates layout state for an existing WebContents registration. Call this on
/// the main thread when the update corresponds to AppKit layout changes.
- (BOOL)updateWebContentsID:(int64_t)webContentsID
                     bounds:(CGRect)bounds
                     visible:(BOOL)visible
                     zIndex:(NSInteger)zIndex;

/// Receives a serialized FTWebViewJavascriptBridge message queue.
- (BOOL)receiveMessageQueue:(NSString *)messageQueue
              webContentsID:(int64_t)webContentsID;

/// Removes one registration or all registrations hosted by an Electron window.
/// Electron Main is responsible for invoking these during WebContents and
/// native-window teardown.
- (void)unregisterWebContentsID:(int64_t)webContentsID;
- (void)unregisterHostView:(NSView *)hostView;
- (void)removeAllRegistrations;

/// Diagnostics and preload bridge configuration.
- (nullable NSNumber *)slotIDForWebContentsID:(int64_t)webContentsID;
- (nullable NSString *)containerViewIDForWebContentsID:(int64_t)webContentsID;
- (NSUInteger)registeredWebContentsCount;
- (NSUInteger)matchedNativeViewCount;
- (NSDictionary<NSString *, id> *)bridgeConfiguration;

@end

NS_ASSUME_NONNULL_END
#endif
