//
//  FTViewTrackingHandler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
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
// Converts a `UIViewController` into RUM view parameters, or filters it out.
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

typedef id<FTUIKitViewTrackingHandler> FTViewTrackingHandler;


NS_ASSUME_NONNULL_END
#endif

#endif
