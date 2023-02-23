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
@property (nonatomic,strong) NSNumber *ft_loadDuration;
@property (nonatomic, copy) NSString *ft_viewUUID;
@end

@protocol FTAutoTrackViewProperty <NSObject>
- (NSString *)ft_actionName;
- (BOOL)isAlertView;
- (BOOL)isAlertClick;
@end

