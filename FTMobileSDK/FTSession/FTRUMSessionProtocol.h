//
//  FTRUMSessionProtocol.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@protocol FTRUMSessionActionDelegate <NSObject>
- (void)applicationDidBecomeActive:(BOOL)isHot;
- (void)applicationWillResignActive;
- (void)notify_viewDidAppear:(UIViewController *)viewController;
- (void)notify_viewDidDisappear:(UIViewController *)viewController;

@end

@protocol FTRUMSessionSourceDelegate <NSObject>


@end

@protocol FTRUMSessionErrorDelegate <NSObject>



@end

@protocol FTRUMSessionViewDelegate <NSObject>



@end
