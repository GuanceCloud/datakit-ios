//
//  FTUIImageResource.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/14.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTUIImageResource.h"
#import "UIImage+FTSRIdentifier.h"
#import "UIColor+FTSRIdentifier.h"
@interface FTUIImageResource(){
    CGColorRef _tintCGColor;
}
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *tintColorIdentifier;

@end
@implementation FTUIImageResource
@synthesize mimeType;

-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor{
    return [self initWithImage:image tintColor:tintColor traitCollection:nil];
}
-(instancetype)initWithImage:(UIImage *)image tintColor:(nullable UIColor *)tintColor traitCollection:(nullable UITraitCollection *)traitCollection{
    self = [super init];
    if(self){
        _image = image;
        UIColor *resolvedTintColor = [tintColor ftsr_resolvedColorWithTraitCollection:traitCollection];
        if (resolvedTintColor.CGColor) {
            _tintCGColor = CGColorRetain(resolvedTintColor.CGColor);
            _tintColorIdentifier = resolvedTintColor.srIdentifier;
        }
    }
    return self;
}
- (void)dealloc{
    if (_tintCGColor) {
        CGColorRelease(_tintCGColor);
    }
}
-(NSString *)mimeType{
    return @"image/png";
}
-(NSData *)calculateData{
    UIColor *tintColor = _tintCGColor ? [UIColor colorWithCGColor:_tintCGColor] : nil;
    if (@available(iOS 13.0, *)) {
        if(self.image.isSymbolImage && tintColor){
            return [[self.image imageWithTintColor:tintColor] ft_pngDataWithTintColor:nil];
        }
    }
    return [self.image ft_pngDataWithTintColor:tintColor];
}
-(NSString *)calculateIdentifier{
    NSString *identifier = [self.image srIdentifier];
    if(self.tintColorIdentifier.length>0){
        identifier = [identifier stringByAppendingString:self.tintColorIdentifier];
    }
    return identifier;
}

@end

#endif
