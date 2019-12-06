//
//  ZYConfig.m
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYConfig.h"

@implementation ZYConfig
- (instancetype)init {
    if (self = [super init]) {
        self.sdkVersion = ZG_SDK_VERSION;
        self.appVersion = ZG_APP_VERSION;
        self.appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        self.channel = ZG_CHANNEL;
        self.sendInterval = 10;
        self.sendMaxSizePerDay = 500;
        self.cacheMaxSize = 500;
        self.sessionEnable = YES;
        self.debug = NO;
        self.apsProduction = YES;
        self.exceptionTrack = NO;
    }
    
    return self;
}
@end
