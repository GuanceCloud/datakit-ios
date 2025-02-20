//
//  ContentViewController.h
//  App
//
//  Created by hulilei on 2025/2/20.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContentViewController : UIViewController
// 页面索引和背景颜色
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, strong) UIColor *bgColor;

- (instancetype)initWithPageIndex:(NSInteger)pageIndex bgColor:(UIColor *)bgColor;
@end

NS_ASSUME_NONNULL_END
