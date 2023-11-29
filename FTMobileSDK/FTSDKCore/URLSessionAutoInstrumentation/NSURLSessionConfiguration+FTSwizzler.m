//
//  NSURLSessionConfiguration+FTSwizzler.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/3/13.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "NSURLSessionConfiguration+FTSwizzler.h"
#import "FTURLProtocol.h"
#import "FTInternalLog.h"
#import "FTSwizzle.h"
@implementation NSURLSessionConfiguration (FTSwizzler)
+(void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = NULL;
        [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(defaultSessionConfiguration) withClassMethod:@selector(ft_defaultSessionConfiguration) error:&error];
        [NSURLSessionConfiguration ft_swizzleClassMethod:@selector(ephemeralSessionConfiguration) withClassMethod:@selector(ft_ephemeralSessionConfiguration) error:&error];
    });
}
+ (NSURLSessionConfiguration *)ft_defaultSessionConfiguration{
    NSURLSessionConfiguration* config = [self ft_defaultSessionConfiguration];
    [config ft_protocolClasses];
    return config;
}
+ (NSURLSessionConfiguration *)ft_ephemeralSessionConfiguration{
    NSURLSessionConfiguration* config = [self ft_ephemeralSessionConfiguration];
    [config ft_protocolClasses];
    return config;
}
- (void)ft_protocolClasses{
    if ([self respondsToSelector:@selector(protocolClasses)]
        && [self respondsToSelector:@selector(setProtocolClasses:)]){
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:self.protocolClasses];
        Class protoCls = FTURLProtocol.class;
        if (![urlProtocolClasses containsObject:protoCls]){
            [urlProtocolClasses insertObject:protoCls atIndex:0];
        }else if ([urlProtocolClasses containsObject:protoCls]){
            NSUInteger index = [urlProtocolClasses indexOfObject:protoCls];
            [urlProtocolClasses exchangeObjectAtIndex:0 withObjectAtIndex:index];
        }
        self.protocolClasses = urlProtocolClasses;
    }else{
        FTInnerLogError(@"NSURLSessionConfiguration get protocolClasses fail");
    }
}
@end
