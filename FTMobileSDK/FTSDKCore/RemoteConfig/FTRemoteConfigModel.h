//
//  FTRemoteConfigModel.h
//
//  Created by hulilei on 2025/12/23.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTRemoteConfigModel : NSObject

@property (nonatomic, copy, nullable) NSString *env;
@property (nonatomic, copy, nullable) NSString *serviceName;
@property (nonatomic, strong, nullable) NSNumber *autoSync;
@property (nonatomic, strong, nullable) NSNumber *compressIntakeRequests;
@property (nonatomic, strong, nullable) NSNumber *syncPageSize;
@property (nonatomic, strong, nullable) NSNumber *syncSleepTime;

@property (nonatomic, strong, nullable) NSNumber *rumSampleRate;
@property (nonatomic, strong, nullable) NSNumber *rumSessionOnErrorSampleRate;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserAction;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserView;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserResource;
@property (nonatomic, strong, nullable) NSNumber *rumEnableResourceHostIP;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppUIBlock;
@property (nonatomic, strong, nullable) NSNumber *rumBlockDurationMs;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppCrash;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppANR;
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceWebView;
@property (nonatomic, copy, nullable) NSArray *rumAllowWebViewHost;

@property (nonatomic, strong, nullable) NSNumber *traceSampleRate;
@property (nonatomic, strong, nullable) NSNumber *traceEnableAutoTrace;
@property (nonatomic, copy, nullable) NSString *traceType;

@property (nonatomic, strong, nullable) NSNumber *logSampleRate;
@property (nonatomic, copy, nullable) NSArray *logLevelFilters;
@property (nonatomic, strong, nullable) NSNumber *logEnableCustomLog;

@end

NS_ASSUME_NONNULL_END
