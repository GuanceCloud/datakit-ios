//
//  FTElectronBridgeServer.h
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

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const
    FTElectronBridgeSocketPathEnvironmentKey;
FOUNDATION_EXPORT NSString *const
    FTElectronBridgeAuthenticationTokenEnvironmentKey;
FOUNDATION_EXPORT NSString *const
    FTElectronBridgeProtocolVersionEnvironmentKey;

/// Optional cross-process bridge for a Native-owned macOS application.
///
/// The application initializes the Guance Native SDK and RUM with their normal
/// APIs before starting this server. The server owns only its local IPC
/// endpoint and remote Electron registrations. It never initializes, flushes,
/// or shuts down the Native SDK.
@interface FTElectronBridgeServer : NSObject

@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;
@property (nonatomic, copy, readonly, nullable) NSString *socketPath;
@property (nonatomic, copy, readonly, nullable)
    NSString *authenticationToken;

/// Starts an owner-only Unix-domain-socket endpoint with generated launch
/// credentials. Starting an already-running instance is idempotent.
- (BOOL)startWithError:(NSError * _Nullable * _Nullable)error;

/// Stops the server, disconnects Electron, removes remote registrations, and
/// deletes the socket. Native SDK state and uploads remain active.
- (void)stop;

/// Returns a copy of `environment` containing the generated endpoint,
/// authentication token, and protocol version.
///
/// Call this only after `startWithError:` succeeds and pass the result to the
/// Electron process at launch. Renderer code must never receive these values.
- (NSDictionary<NSString *, NSString *> *)environmentByAddingToEnvironment:
    (nullable NSDictionary<NSString *, NSString *> *)environment;

@end

NS_ASSUME_NONNULL_END

#endif
