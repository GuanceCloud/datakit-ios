//
//  ZYConfig.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTBaseInfoHander.h"
#import "ZYLog.h"
@implementation FTMobileConfig
- (instancetype)init {
    if (self = [super init]) {
        self.sdkVersion = FT_SDK_VERSION;
        self.appVersion = FT_APP_VERSION;
        self.appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        self.isDebug = NO;
//        self.enableTrackAppCrash = NO;
        self.autoTrackEventType = FTAutoTrackTypeNone;
        self.enableAutoTrack = NO;
    }
    
    return self;
}
-(void)setIsDebug:(BOOL)isDebug{
     SETISDEBUG(isDebug);
}
@end
