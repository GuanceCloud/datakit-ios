//
//  FTGlobalManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/6.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTGlobalManager.h"
@implementation FTGlobalManager
+ (instancetype)sharedInstance{
    static FTGlobalManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = [rumConfig copy];
}
-(void)setTraceConfig:(FTTraceConfig *)traceConfig{
    _traceConfig = [traceConfig copy];
}
@end
