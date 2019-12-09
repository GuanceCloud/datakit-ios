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
        self.sdkVersion = ZY_SDK_VERSION;
        self.appVersion = ZY_APP_VERSION;
        self.appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        self.channel = ZG_CHANNEL;
    

    }
    
    return self;
}
@end
