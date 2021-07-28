//
//  UIApplication+FTAutoTrack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (FTAutoTrack)
-(BOOL)dataflux_sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event;
- (void)ftTrack:(SEL)action to:(id)to from:(id )sender forEvent:(UIEvent *)event;
@end

NS_ASSUME_NONNULL_END
