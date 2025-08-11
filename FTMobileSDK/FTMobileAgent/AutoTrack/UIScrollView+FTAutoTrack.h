//
//  UIScrollView+FTAutoTrack.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITableView (FTAutoTrack)

- (void)ft_setDelegate:(id <UITableViewDelegate>)delegate;

@end

@interface UICollectionView (FTAutoTrack)

- (void)ft_setDelegate:(id <UICollectionViewDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
