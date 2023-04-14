//
//  NSURLSessionConfiguration+FTSwizzler.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/3/13.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "NSURLSessionConfiguration+FTSwizzler.h"
#import "FTURLProtocol.h"
#import "FTLog.h"
@implementation NSURLSessionConfiguration (FTSwizzler)
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
        ZYLogError(@"NSURLSessionConfiguration get protocolClasses fail");
    }
}
@end
