//
//  FTTraceHandlerManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/2.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandlerManager.h"
#import "FTTraceHeaderManager.h"
@interface FTTraceHandlerManager ()
@end
@implementation FTTraceHandlerManager
+ (instancetype)sharedManager{
    static dispatch_once_t onceToken;
    static FTTraceHandlerManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTTraceHandlerManager alloc]init];
    });
    return sharedManager;
}

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    return [[FTTraceHeaderManager sharedInstance] networkTrackHeaderWithUrl:url];
}
@end
