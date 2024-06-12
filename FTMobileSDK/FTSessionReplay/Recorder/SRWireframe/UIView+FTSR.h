//
//  UIView+FTSR.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (FTSR)
@property(nonatomic, assign) int SRViewID;
@property(nonatomic, strong) NSArray* SRViewIDs;
@property(nonatomic, assign, readonly) BOOL usesDarkMode;
@end

NS_ASSUME_NONNULL_END
