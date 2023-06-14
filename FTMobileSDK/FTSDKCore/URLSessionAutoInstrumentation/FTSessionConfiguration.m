//
//  FTSessionConfiguration.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTSessionConfiguration.h"
#import <objc/runtime.h>
#import "FTURLProtocol.h"
#import "FTSwizzle.h"
#import "NSURLSessionConfiguration+FTSwizzler.h"
@implementation FTSessionConfiguration
+ (FTSessionConfiguration *)defaultConfiguration {
    static FTSessionConfiguration *staticConfiguration;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        staticConfiguration=[[FTSessionConfiguration alloc] init];
    });
    return staticConfiguration;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _isExchanged = NO;
    }
    return self;
}
- (void)load {
    self.isExchanged=YES;
    NSError *error = NULL;
    [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(defaultSessionConfiguration) withClassMethod:@selector(ft_defaultSessionConfiguration) error:&error];
    [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(ephemeralSessionConfiguration) withClassMethod:@selector(ft_ephemeralSessionConfiguration) error:&error];
}
- (void)unload {
    self.isExchanged=NO;
    NSError *error = NULL;
    [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(defaultSessionConfiguration) withClassMethod:@selector(ft_defaultSessionConfiguration) error:&error];
    [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(ephemeralSessionConfiguration) withClassMethod:@selector(ft_ephemeralSessionConfiguration) error:&error];
}
@end
