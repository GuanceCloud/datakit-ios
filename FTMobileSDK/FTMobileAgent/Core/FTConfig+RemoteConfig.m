//
//  FTConfig+RemoteConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTConfig+RemoteConfig.h"
#import "FTMobileConfig.h"
#import "FTLoggerConfig.h"
#import "FTRumConfig.h"
#import "FTJSONUtil.h"
#import "FTLog+Private.h"

@implementation FTMobileConfig (RemoteConfig)

-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        if (model.env && model.env.length>0) {
            self.env = model.env;
        }
        if (model.serviceName && model.serviceName.length>0) {
            self.service = model.serviceName;
        }
        if (model.autoSync != nil) {
            self.autoSync = [model.autoSync boolValue];
        }
        if (model.compressIntakeRequests != nil) {
            self.compressIntakeRequests = [model.compressIntakeRequests boolValue];
        }
        if (model.syncPageSize != nil) {
            self.syncPageSize = [model.syncPageSize intValue];
        }
        if (model.syncSleepTime != nil) {
            self.syncSleepTime = [model.syncSleepTime intValue];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"mergeRemoteConfigIntoCoreConfig fail");
    }
}

@end

@implementation FTLoggerConfig (RemoteConfig)

-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        
        if (model.logSampleRate != nil) {
            self.samplerate = [model.logSampleRate doubleValue] * 100;
        }
        if (model.logEnableCustomLog != nil) {
            self.enableCustomLog = [model.logEnableCustomLog boolValue];
        }
        if (model.logLevelFilters) {
            self.logLevelFilter = model.logLevelFilters;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"mergeRemoteConfigIntoLoggerConfig fail");
    }
}
@end

@implementation FTRumConfig (RemoteConfig)

-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        if (model.rumSampleRate != nil) {
            self.samplerate = [model.rumSampleRate doubleValue] * 100;
        }
        if (model.rumSessionOnErrorSampleRate != nil) {
            self.sessionOnErrorSampleRate = [model.rumSessionOnErrorSampleRate doubleValue] * 100;
        }
        if (model.rumEnableTraceUserAction != nil) {
            self.enableTraceUserAction = [model.rumEnableTraceUserAction boolValue];
        }
        if (model.rumEnableTraceUserView != nil) {
            self.enableTraceUserView = [model.rumEnableTraceUserView boolValue];
        }
        if (model.rumEnableTraceUserResource != nil) {
            self.enableTraceUserResource = [model.rumEnableTraceUserResource boolValue];
        }
        if (model.rumEnableResourceHostIP != nil) {
           self.enableResourceHostIP = [model.rumEnableResourceHostIP boolValue];
        }
        if (model.rumEnableTrackAppUIBlock != nil) {
           self.enableTrackAppFreeze = [model.rumEnableTrackAppUIBlock boolValue];
        }
        if (model.rumBlockDurationMs != nil) {
           self.freezeDurationMs = [model.rumBlockDurationMs longValue];
        }
        if (model.rumEnableTrackAppCrash != nil) {
           self.enableTrackAppCrash = [model.rumEnableTrackAppCrash boolValue];
        }
        if (model.rumEnableTrackAppANR != nil) {
           self.enableTrackAppANR = [model.rumEnableTrackAppANR boolValue];
        }
        if (model.rumEnableTraceWebView != nil) {
           self.enableTraceWebView = [model.rumEnableTraceWebView boolValue];
        }
        if (model.rumAllowWebViewHost) {
           self.allowWebViewHost = model.rumAllowWebViewHost;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"mergeRemoteConfigIntoRUMConfig fail");
    }
}

@end

@implementation FTTraceConfig (RemoteConfig)

-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model{
    @try {
        if (model.traceSampleRate != nil) {
            self.samplerate = [model.traceSampleRate doubleValue] * 100;
        }
        if (model.traceEnableAutoTrace != nil) {
            self.enableAutoTrace = [model.traceEnableAutoTrace boolValue];
        }
        if (model.traceType) {
            FTNetworkTraceType networkTraceType = FTNetworkTraceTypeDDtrace;
            NSString *trace = [model.traceType lowercaseString];
            if ([trace isEqualToString:@"ddtrace"]) {
                networkTraceType = FTNetworkTraceTypeDDtrace;
            }else if ([trace isEqualToString:@"zipkinmutiheader"]){
                networkTraceType = FTNetworkTraceTypeZipkinMultiHeader;
            }else if ([trace isEqualToString:@"zipkinsingleheader"]){
                networkTraceType = FTNetworkTraceTypeZipkinSingleHeader;
            }else if ([trace isEqualToString:@"traceparent"]){
                networkTraceType = FTNetworkTraceTypeTraceparent;
            }else if ([trace isEqualToString:@"skywalking"]){
                networkTraceType = FTNetworkTraceTypeSkywalking;
            }else if ([trace isEqualToString:@"jaeger"]){
                networkTraceType = FTNetworkTraceTypeJaeger;
            }
            self.networkTraceType = networkTraceType;
        }
        
    } @catch (NSException *exception) {
        FTInnerLogError(@"mergeRemoteConfigIntoTraceConfig fail");
    }
}
@end
