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
- (void)ftApplicationDidBecomeActive:(BOOL)isHot;
- (void)ftApplicationWillTerminate;
- (void)ftViewDidAppear:(UIViewController *)viewController;
- (void)ftViewDidDisappear:(UIViewController *)viewController;
- (void)ftClickView:(UIView *)clickView;
@end

@protocol FTRUMSessionResourceDelegate <NSObject>
- (void)ftResourceCreate:(FTTaskInterceptionModel *)resourceModel;
- (void)ftResourceCompleted:(FTTaskInterceptionModel *)resourceModel;

@end

@protocol FTRUMSessionErrorDelegate <NSObject>

- (void)ftErrorWithtags:(NSDictionary *)tags field:(NSDictionary *)field;
- (void)ftLongTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field;

@end

@protocol FTRUMWebViewJSBridgeDataDelegate <NSObject>

- (void)ftWebviewDataWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

@end

