//
//  FTAutoTrackProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/11.
//  Copyright © 2021 hll. All rights reserved.
//
#import <Foundation/Foundation.h>

@protocol FTAutoTrackViewControllerProperty <NSObject>
@property (nonatomic,strong) NSDate * ft_viewLoadStartTime;
@property (nonatomic, copy) NSString *ft_viewUUID;
@property (nonatomic, copy, readonly) NSString *ft_viewControllerId;
@property (nonatomic, copy, readonly) NSString *ft_parentVC;
@end

@protocol FTAutoTrackViewProperty <NSObject>

@property (nonatomic, readonly) UIViewController *ft_currentViewController;
@property (nonatomic, copy, readonly) NSString *ft_parentsView;
@end

