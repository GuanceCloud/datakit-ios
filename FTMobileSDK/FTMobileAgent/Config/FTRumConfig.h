//
//  FTRumConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Device information in ERROR
typedef NS_OPTIONS(NSUInteger, FTErrorMonitorType) {
    /// Enable all monitoring: battery, memory, CPU usage
    FTErrorMonitorAll          = 0xFFFFFFFF,
    /// Battery level
    FTErrorMonitorBattery      = 1 << 1,
    /// Total memory, memory usage
    FTErrorMonitorMemory       = 1 << 2,
    /// CPU usage
    FTErrorMonitorCpu          = 1 << 3,
};

/// Device information monitoring items
typedef NS_OPTIONS(NSUInteger, FTDeviceMetricsMonitorType){
    /// Enable all monitoring items: memory, CPU, FPS
    FTDeviceMetricsMonitorAll      = 0xFFFFFFFF,
    /// Average memory, peak memory
    FTDeviceMetricsMonitorMemory   = 1 << 2,
    /// CPU maximum fluctuation, average
    FTDeviceMetricsMonitorCpu      = 1 << 3,
    /// FPS minimum frame rate, average frame rate
    FTDeviceMetricsMonitorFps      = 1 << 4,
};
/// Monitoring item sampling frequency
typedef NS_ENUM(NSUInteger, FTMonitorFrequency) {
    /// 500ms (default)
    FTMonitorFrequencyDefault,
    /// 100ms
    FTMonitorFrequencyFrequent,
    /// 1000ms
    FTMonitorFrequencyRare,
};

/// RUM discard strategy
typedef NS_ENUM(NSInteger, FTRUMCacheDiscard)  {
    /// Default, when log data count exceeds maximum (100_000), new data is not written
    FTRUMDiscard,
    /// When log data exceeds maximum, discard old data
    FTRUMDiscardOldest
};

#import "FTActionTrackingStrategy.h"
#import "FTViewTrackingStrategy.h"

NS_ASSUME_NONNULL_BEGIN
/// RUM filter resource callback, returns: NO means to collect, YES means not to collect.
typedef BOOL(^FTResourceUrlHandler)(NSURL * url);
/// RUM Resource custom add extra properties
typedef NSDictionary<NSString *,id>* _Nullable (^FTResourcePropertyProvider)( NSURLRequest * _Nullable request, NSURLResponse * _Nullable response,NSData *_Nullable data, NSError *_Nullable error);
/// Support custom intercept `URLSessionTask` Error, confirm interception returns YES, not intercepted returns NO
typedef BOOL (^FTSessionTaskErrorFilter)(NSError *_Nonnull error);


/// RUM functionality configuration items
@interface FTRumConfig : NSObject
/// Designated initializer, set appid
///
/// - Parameters:
///   - appid: User access monitoring application ID unique identifier, automatically generated when creating monitoring in the user access monitoring console.
/// - Returns: rum configuration items.
- (instancetype)initWithAppid:(nonnull NSString *)appid;
/// Disable new initialization
+ (instancetype)new NS_UNAVAILABLE;
/// User access monitoring application ID unique identifier, automatically generated when creating monitoring in the user access monitoring console.
@property (nonatomic, copy) NSString *appid;
/// Sampling configuration, property values: 0 to 100, 100 means 100% collection, no data sample compression.
@property (nonatomic, assign) int samplerate;
/// Collect sessions that have errors
/// When the feature is enabled, if a Session that was not originally selected by the sampling rate encounters an error, the SDK will collect data from these originally uncollected Sessions
@property (nonatomic, assign) int sessionOnErrorSampleRate;
/// Set whether to track user actions, currently supports app launch and click actions,
/// Only effective when View events are present
@property (nonatomic, assign) BOOL enableTraceUserAction;
/// Set whether to track page lifecycle (only applies to autotrack)
@property (nonatomic, assign) BOOL enableTraceUserView;
/// Set whether to track user network requests (only applies to native http)
@property (nonatomic, assign) BOOL enableTraceUserResource;
/// Set whether to collect network request Host IP (only applies to native http, iOS 13 and above)
@property (nonatomic, assign) BOOL enableResourceHostIP;
/// Custom collection resource rules.
/// Determine whether to collect corresponding resource data based on the requested resource URL, default is to collect all. Returns: NO means to collect, YES means not to collect.
@property (nonatomic, copy) FTResourceUrlHandler resourceUrlHandler;
/// Set whether to collect crash logs
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/// Set whether to collect freezes
@property (nonatomic, assign) BOOL enableTrackAppFreeze;
/// Set freeze threshold. Unit milliseconds 100 < freezeDurationMs, default 250ms
@property (nonatomic, assign) long freezeDurationMs;
/// Set whether to collect ANR
///
/// runloop collects main thread freezes
@property (nonatomic, assign) BOOL enableTrackAppANR;
/// Device information in ERROR
@property (nonatomic, assign) FTErrorMonitorType errorMonitorType;
/// Set monitoring type, if not set then monitoring is not enabled
@property (nonatomic, assign) FTDeviceMetricsMonitorType deviceMetricsMonitorType;
/// Set monitoring sampling frequency
@property (nonatomic, assign) FTMonitorFrequency monitorFrequency;
/// Set rum global tags
///
/// Reserved tags: special key - track_id (for tracking functionality)
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;
/// RUM maximum cache limit, default 100_000
@property (nonatomic, assign) int rumCacheLimitCount;
/// RUM discard strategy
@property (nonatomic, assign) FTRUMCacheDiscard rumDiscardType;
/// RUM Resource add custom properties
@property (nonatomic, copy) FTResourcePropertyProvider resourcePropertyProvider;
/// Intercept SessionTask Error, confirm interception returns YES, not intercepted returns NO
@property (nonatomic, copy) FTSessionTaskErrorFilter sessionTaskErrorFilter;

/// Set whether to enable WebView data collection, default YES
@property (nonatomic, assign) BOOL enableTraceWebView;
/// Set specific hosts or domains allowed to collect WebView data, nil means collect all.
@property (nonatomic, copy) NSArray *allowWebViewHost;

/// A strategy for user-defined collection of `ViewControllers` as RUM views for tracking.
/// It takes effect when enableTraceUserView = YES.
/// RUM will call this callback for each `ViewController` presented in the application.
///  - If the given controller needs to start a RUM view, return the FTRUMView parameters;
///  - Return nil to ignore it.
@property (nonatomic, weak) FTViewTrackingStrategy viewTrackingStrategy;

/// The strategy deciding if a given RUM Action should be recorded.
/// It takes effect when enableTraceUserAction = YES.
///  - If need to Start a RUM action, return the FTRUMAction parameters;
///  - Return nil to ignore it.
@property (nonatomic, weak) FTActionTrackingStrategy actionTrackingStrategy;

/// Enable freeze collection and set freeze threshold.
/// - Parameter enableTrackAppFreeze: Set whether to collect freezes
/// - Parameter freezeDurationMs: Freeze threshold, unit milliseconds 100 < freezeDurationMs, default 250ms
-(void)setEnableTrackAppFreeze:(BOOL)enableTrackAppFreeze freezeDurationMs:(long)freezeDurationMs;
@end
NS_ASSUME_NONNULL_END
