//
//  FTUIImageResource.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/14.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUIImageResource.h"
#import "UIImage+FTSRIdentifier.h"
#import "UIColor+FTSRIdentifier.h"
@interface FTUIImageResource()
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *tintColor;

@end
@implementation FTUIImageResource
@synthesize mimeType;

-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor{
    self = [super init];
    if(self){
        _image = image;
        _tintColor = tintColor;
    }
    return self;
}
-(NSString *)mimeType{
    return @"image/png";
}
-(NSData *)calculateData{
    if (@available(iOS 13.0, *)) {
        if(self.image.isSymbolImage && self.tintColor){
            return [[self.image imageWithTintColor:self.tintColor] ft_pngDataWithTintColor:nil];
        }
    }
    return [self.image ft_pngDataWithTintColor:self.tintColor];
}
-(NSString *)calculateIdentifier{
    NSString *identifier = [self.image srIdentifier];
    if(self.tintColor){
        identifier = [identifier stringByAppendingString:[self.tintColor srIdentifier]];
    }
    return identifier;
}

@end
