//
//  FTUIImageResource.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/14.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUIImageResource.h"
#import "FTSRWireframesBuilder.h"
@interface FTUIImageResource()
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *tintColor;
@end
@implementation FTUIImageResource

-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor{
    self = [super init];
    if(self){
        _image = image;
        _tintColor = tintColor;
    }
    return self;
}
-(NSData *)calculateData{
    
}
-(NSString *)calculateIdentifier{
    return @"";
}
@end
