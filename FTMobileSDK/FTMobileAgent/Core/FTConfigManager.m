//
//  FTConfigManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/6.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTConfigManager.h"

@implementation FTConfigManager
+ (instancetype)sharedInstance{
    static FTConfigManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}
-(void)setTrackConfig:(FTMobileConfig *)trackConfig{
    _trackConfig = [trackConfig copy];
}
@end
