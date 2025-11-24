//
//  FTMobileConfig.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Network link tracing usage type
typedef NS_ENUM(NSUInteger, FTNetworkTraceType) {
    /// datadog trace
    FTNetworkTraceTypeDDtrace,
    /// zipkin multi header
    FTNetworkTraceTypeZipkinMultiHeader,
    /// zipkin single header
    FTNetworkTraceTypeZipkinSingleHeader,
    /// w3c traceparent
    FTNetworkTraceTypeTraceparent,
    /// skywalking 8.0+
    FTNetworkTraceTypeSkywalking,
    /// jaeger
    FTNetworkTraceTypeJaeger,
};
/// Environment. Property values: prod/gray/pre/common/local.
typedef NS_ENUM(NSInteger, FTEnv) {
    /// Production environment
    FTEnvProd         = 0,
    /// Gray environment
    FTEnvGray,
    /// Pre-release environment
    FTEnvPre,
    /// Daily environment
    FTEnvCommon,
    /// Local environment
    FTEnvLocal,
};
/// Data synchronization size
typedef NS_ENUM(NSUInteger, FTSyncPageSize) {
    /// MINI 5
    FTSyncPageSizeMini = 0,
    /// MEDIUM 10
    FTSyncPageSizeMedium,
    /// MAX 50
    FTSyncPageSizeMax,
};

/// DB discard strategy
typedef NS_ENUM(NSInteger, FTDBCacheDiscard)  {
    /// Default, when database storage exceeds maximum (default 100MB), new data is not written
    FTDBDiscard,
    /// When database storage exceeds maximum, discard old data
    FTDBDiscardOldest
};
#import "FTDataModifier.h"

NS_ASSUME_NONNULL_BEGIN
@class FTTraceContext;
/// Support custom trace, after confirming interception, returns TraceContext, returns nil if not intercepted
typedef FTTraceContext*_Nullable(^FTTraceInterceptor)(NSURLRequest *_Nonnull request);

/// Trace functionality configuration items
@interface FTTraceConfig : NSObject
/// Disable new initialization
+ (instancetype)new NS_UNAVAILABLE;
/// Sampling configuration, property values: 0 to 100, 100 means 100% collection, no data sample compression.
@property (nonatomic, assign) int samplerate;
/// Set network request information collection to use link tracing type, default is DDtrace
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
/// Support custom trace through URLRequest, after confirming interception, returns TraceContext, returns nil if not intercepted
@property (nonatomic,copy) FTTraceInterceptor traceInterceptor;
/// Whether to associate Trace data with rum
///
/// Only effective when FTNetworkTraceType is set to FTNetworkTraceTypeDDtrace
@property (nonatomic, assign) BOOL enableLinkRumData;
/// Set whether to enable automatic http trace
@property (nonatomic, assign) BOOL enableAutoTrace;
@end

/// SDK basic configuration items
@interface FTMobileConfig : NSObject
/// Designated initializer, set metricsUrl
/// - Parameter metricsUrl: Data reporting address
- (instancetype)initWithMetricsUrl:(NSString *)metricsUrl DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -initWithDatakitUrl: instead");

/// Local environment deployment, set datakitUrl
/// - Parameter datakitUrl: datakit data reporting address
- (instancetype)initWithDatakitUrl:(NSString *)datakitUrl;

/// Use public network DataWay deployment, set datawayUrl and clientToken
/// - Parameter datawayUrl: datawayUrl data reporting address
/// - Parameter clientToken: dataway token
- (instancetype)initWithDatawayUrl:(NSString *)datawayUrl clientToken:(NSString *)clientToken;

/// Disable init initialization
- (instancetype)init NS_UNAVAILABLE;

/// Disable new initialization
+ (instancetype)new NS_UNAVAILABLE;
/// Data reporting address
@property (nonatomic, copy) NSString *metricsUrl DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use datakitUrl instead");
/// Data reporting datakit address
@property (nonatomic, copy) NSString *datakitUrl;
/// Data reporting dataway address
@property (nonatomic, copy) NSString *datawayUrl;
/// client token
@property (nonatomic, copy) NSString *clientToken;
/// Set custom environment field.
@property (nonatomic, copy) NSString *env;
/// Set whether to allow SDK to print Debug logs.
@property (nonatomic, assign) BOOL enableSDKDebugLog;
/// Application version number. Default `CFBundleShortVersionString` value
@property (nonatomic, copy) NSString *version DEPRECATED_MSG_ATTRIBUTE("Deprecated, version will uniformly use `CFBundleShortVersionString` value");
/// Business or service name, default: df_rum_ios
@property (nonatomic, copy) NSString *service;
/// Whether data is automatically synchronized and uploaded, default: YES
@property (nonatomic, assign) BOOL autoSync;
/// Number of items synchronized per request during data synchronization, minimum 5, default: 10
@property (nonatomic, assign) int syncPageSize;
/// Interval time between requests during data synchronization, unit milliseconds 0< syncSleepTime <5000
@property (nonatomic, assign) int syncSleepTime;
/// Whether to enable data integer compatibility during data synchronization, default YES
@property (nonatomic, assign) BOOL enableDataIntegerCompatible;
/// Set whether to enable compression during internal data synchronization, default: NO
@property (nonatomic, assign) BOOL compressIntakeRequests;
/// Enable using db to limit data size
@property (nonatomic, assign) BOOL enableLimitWithDbSize;
/// db cache limit size, default 100MB, unit byte
@property (nonatomic, assign) long dbCacheLimit;
/// Database discard strategy
@property (nonatomic, assign) FTDBCacheDiscard dbDiscardType;

/// Set SDK global tags
///
/// Reserved tags: sdk_package_flutter, sdk_package_react_native
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;

/// AppGroups Identifier array for Extensions that need to be collected
@property (nonatomic, copy) NSArray<NSString*> *groupIdentifiers;

/// Set data modifier, field replacement, suitable for global field replacement scenarios
@property (nonatomic, copy) FTDataModifier dataModifier;

/// Set data modifier, can make judgments for a specific row, then decide whether to replace a certain value
@property (nonatomic, copy) FTLineDataModifier lineDataModifier;

/// Set whether to enable remote dynamic configuration
@property (nonatomic, assign) BOOL remoteConfiguration;

/// Set remote dynamic configuration minimum update interval, unit seconds, default 12*60*60
@property (nonatomic, assign) int remoteConfigMiniUpdateInterval;
/// Set env based on provided FTEnv type
/// - Parameter envType: Environment
- (void)setEnvWithType:(FTEnv)envType;
/// Set syncPageSize based on provided FTSyncPageSize type
/// - Parameter pageSize: Data synchronization size
- (void)setSyncPageSizeWithType:(FTSyncPageSize)pageSize;

@end

NS_ASSUME_NONNULL_END
