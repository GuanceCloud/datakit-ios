//
//  FTUIImageResource.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/14.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUIImageResource.h"
#import "FTSRWireframesBuilder.h"
#import "UIImage+FTSRIdentifier.h"
#import "UIColor+FTSRIdentifier.h"
@interface FTUIImageResource()
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) NSUInteger desiredMaxBytesSize;

@end
@implementation FTUIImageResource

-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor{
    self = [super init];
    if(self){
        _image = image;
        _tintColor = tintColor;
        _desiredMaxBytesSize = 10 * 1024 * 1024;
    }
    return self;
}
-(NSData *)calculateData{
    if(!self.tintColor){
        return [self.image ft_scaledDownToApproximateSize:_desiredMaxBytesSize tintColor:nil];
    }
    if (@available(iOS 13.0, *)) {
        if(self.image.isSymbolImage && self.tintColor){
            return [[self.image imageWithTintColor:self.tintColor] ft_scaledDownToApproximateSize:_desiredMaxBytesSize tintColor:nil];
        }
    }
    return [self.image ft_scaledDownToApproximateSize:_desiredMaxBytesSize tintColor:self.tintColor];
}
-(NSString *)calculateIdentifier{
    NSString *identifier = [self.image srIdentifier];
    if(self.tintColor){
        identifier = [identifier stringByAppendingString:[self.tintColor srIdentifier]];
    }
    return identifier;
}
@end
