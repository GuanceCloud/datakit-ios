//
//  FTViewTrackingHandler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
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

typedef id<FTUIKitViewTrackingHandler> FTViewTrackingHandler;


NS_ASSUME_NONNULL_END
#endif
