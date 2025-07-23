//
//  ContentViewController.m
//  App
//
//  Created by hulilei on 2025/2/20.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import "ContentViewController.h"

@interface ContentViewController ()

@end

@implementation ContentViewController

// Lazy loading UILabel
- (UILabel *)createLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (instancetype)initWithPageIndex:(NSInteger)pageIndex bgColor:(UIColor *)bgColor {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _pageIndex = pageIndex;
        _bgColor = bgColor;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSAssert(NO, @"init(coder:) has not been implemented");
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = self.bgColor;
    
    UILabel *label = [self createLabel];
    label.text = [NSString stringWithFormat:@"Page %ld", (long)self.pageIndex];
    label.frame = CGRectMake(0, 0, 200, 50);
    label.center = self.view.center;
    [self.view addSubview:label];
}

@end
