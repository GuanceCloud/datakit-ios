//
//  FTViewTrackingHandler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#ifndef FTViewTrackingHandler_h
#define FTViewTrackingHandler_h

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_TV || TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import "FTRUMView.h"

NS_ASSUME_NONNULL_BEGIN

/// The handler deciding if a given RUM View should be recorded.
@protocol FTUIKitViewTrackingHandler <NSObject>
/// Converts a `UIViewController` into RUM view parameters, or filters it out.
///
/// - Parameter viewController: The view controller that has appeared in the UI.
/// - Returns: RUM view parameters if the view controller should be tracked, or `nil` to ignore it.
- (nullable FTRUMView *)rumViewForViewController:(UIViewController *)viewController;

@end

/// Experimental: The handler deciding if an automatically extracted SwiftUI View name should be recorded as a RUM View.
///
/// Set this only when your app needs automatic SwiftUI View tracking.
/// If you do not need custom filtering or naming, use `FTDefaultSwiftUIViewTrackingHandler`.
/// This experimental API may change in future releases.
@protocol FTSwiftUIViewTrackingHandler <NSObject>

/// Experimental: Deciding if the SwiftUI RUM View should be recorded.
- (nullable FTRUMView *)rumViewForExtractedViewName:(NSString *)extractedViewName;
@end

/// Handler that decides whether automatically detected UIKit views are recorded as RUM views.
typedef id<FTUIKitViewTrackingHandler> FTViewTrackingHandler;


NS_ASSUME_NONNULL_END
#else
NS_ASSUME_NONNULL_BEGIN

@protocol FTUIKitViewTrackingHandler <NSObject>
@end

@protocol FTSwiftUIViewTrackingHandler <NSObject>
@end

/// Placeholder view tracking handler for platforms without UIKit view tracking.
typedef id<FTUIKitViewTrackingHandler> FTViewTrackingHandler;

NS_ASSUME_NONNULL_END
#endif

#endif
