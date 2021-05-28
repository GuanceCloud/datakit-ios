//
//  FTRUMSessionProtocol.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTTaskInterceptionModel;
@protocol FTRUMSessionActionDelegate <NSObject>
- (void)notify_applicationDidBecomeActive:(BOOL)isHot;
- (void)notify_applicationWillResignActive;
- (void)notify_viewDidAppear:(UIViewController *)viewController;
- (void)notify_viewDidDisappear:(UIViewController *)viewController;
- (void)notify_clickView:(UIView *)clickView;
@end

@protocol FTRUMSessionResourceDelegate <NSObject>
- (void)notify_resourceCreate:(FTTaskInterceptionModel *)resourceModel;
- (void)notify_resourceCompleted:(FTTaskInterceptionModel *)resourceModel;

@end

@protocol FTRUMSessionErrorDelegate <NSObject>

- (void)notify_errorWithtags:(NSDictionary *)tags field:(NSDictionary *)field;
- (void)notify_longTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field;

@end

@protocol FTRUMWebViewJSBridgeDataDelegate <NSObject>

- (void)webviewDataWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

@end

