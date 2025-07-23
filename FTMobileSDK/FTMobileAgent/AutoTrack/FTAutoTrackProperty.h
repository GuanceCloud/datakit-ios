//
//  FTAutoTrackProperty.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/3/11.
//  Copyright © 2021 hll. All rights reserved.
//
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@protocol FTRumViewProperty <NSObject>
@property (nonatomic,strong,nullable) NSDate * ft_viewLoadStartTime;
@property (nonatomic,strong,nullable) NSNumber *ft_loadDuration;
@property (nonatomic, copy) NSString *ft_viewUUID;
@end

@protocol FTRUMActionProperty <NSObject>
@optional
- (nullable NSString *)actionName;
- (NSString *)ft_actionName;
- (BOOL)isAlertView;
- (BOOL)isAlertClick;
@end
NS_ASSUME_NONNULL_END
