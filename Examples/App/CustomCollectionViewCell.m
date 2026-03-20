//
//  CustomCollectionViewCell.m
//  App
//
//  Created by hulilei on 2026/3/16.
//  Copyright © 2026 GuanceCloud. All rights reserved.
//

#import "CustomCollectionViewCell.h"

@implementation CustomCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupImageView];
    }
    return self;
}

- (void)setupImageView {
    
    self.cellImageView = [[UIImageView alloc] init];
    self.cellImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cellImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.cellImageView.clipsToBounds = YES;
    
   
    if (@available(iOS 13.0, *)) {
        self.cellImageView.image = [UIImage systemImageNamed:@"star.fill"];
        self.cellImageView.tintColor = [UIColor systemBlueColor];
    } else {
        self.cellImageView.image = [UIImage imageNamed:@"star"];
    }
    
    [self.contentView addSubview:self.cellImageView];
    
    NSArray *constraints = @[
        [self.cellImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.cellImageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.cellImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.cellImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8]
    ];
    
    [NSLayoutConstraint activateConstraints:constraints];
}
@end
