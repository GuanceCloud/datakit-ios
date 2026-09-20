//
//  FTAppLifeCycle.h
//  FTSDK
//
//  Created by hulilei on 2021/9/17.
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
#import "FTSDKCompat.h"
NS_ASSUME_NONNULL_BEGIN
/// APP lifecycle protocol
@protocol FTAppLifeCycleDelegate <NSObject>
@optional
/// App did finish launching
- (void)applicationDidFinishLaunching;
/// App will terminate
- (void)applicationWillTerminate;

/// App becomes active
- (void)applicationDidBecomeActive;

/// App will resign active
- (void)applicationWillResignActive;

#if FT_HAS_UIKIT
/// App will enter foreground
- (void)applicationWillEnterForeground;
/// App enters background
- (void)applicationDidEnterBackground;
#endif

@end
/// App lifecycle monitoring utility
@interface FTAppLifeCycle : NSObject
/// Singleton
+ (instancetype)sharedInstance;
/// Add delegate class that conforms to FTAppLifeCycleDelegate protocol
/// - Parameter delegate: Delegate class that conforms to FTAppLifeCycleDelegate protocol
- (void)addAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;
/// Remove delegate class that conforms to FTAppLifeCycleDelegate protocol
/// - Parameter delegate: Delegate class that conforms to FTAppLifeCycleDelegate protocol
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
