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
- (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl akId:(NSString *)akId akSecret:(NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning{
     if (self = [super init]) {
         self.metricsUrl = metricsUrl;
         self.akId = akId;
         self.akSecret = akSecret;
         self.enableRequestSigning = enableRequestSigning;
         self.sdkVersion = FT_SDK_VERSION;
         self.appVersion = FT_APP_VERSION;
         self.appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
         self.enableLog = NO;
         self.autoTrackEventType = FTAutoTrackTypeNone;
         self.enableAutoTrack = NO;
         self.needBindUser = YES;
         self.needViewFlow = NO;
        }
      return self;
}
#pragma mark NSCopying
- (id)copyWithZone:(nullable NSZone *)zone {
    FTMobileConfig *options = [[[self class] allocWithZone:zone] init];
    options.metricsUrl = self.metricsUrl;
    options.autoTrackEventType = self.autoTrackEventType;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.akId = self.akId;
    options.akSecret = self.akSecret;
    options.enableRequestSigning = self.enableRequestSigning;

    options.sdkVersion = self.sdkVersion;
    options.appVersion = self.sdkVersion;
    
    options.appName = self.appName;
    options.enableLog = self.enableLog;
    options.needBindUser = self.needBindUser;
    return options;
}

-(void)enableLog:(BOOL)enableLog{
     SETISDEBUG(enableLog);
}
@end
