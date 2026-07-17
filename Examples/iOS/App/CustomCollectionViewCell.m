//
//  CustomCollectionViewCell.m
//  App
//
//  Created by hulilei on 2026/3/16.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
