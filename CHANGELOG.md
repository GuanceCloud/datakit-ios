# 1.5.18
1. Added support for RUM View/Action collection filtering and custom View/Action naming via `FTRumConfig.viewTrackingHandler` and `FTRumConfig.actionTrackingHandler`
2. Added the `-updateViewLoadingTime:` method to support updating the loading time for the currently active RUM View
3. Made `sdk_name` a mandatory basic field
4. Fixed the UserScripts conflict issue in WebView data collection
5. Fixed the thread-safety issue of SDK shutdown operations
6. Fixed the crash caused by modifying the name of the main thread during Long task monitoring
---
# 1.5.18-beta.1
1. Same as 1.5.18-alpha.6
---
# 1.5.18-alpha.6
1. Add custom RUM Launch Action handler via `FTRumConfig.actionTrackingHandler` 
---
# 1.5.18-alpha.5
1. Changes `FTRumConfig.viewTrackingStrategy` implementation from block to delegate protocol and Changes `FTRumConfig.viewTrackingStrategy` to `FTRumConfig.viewTrackingHandler`
2. Added support for custom RUM Action tracking handler via `FTRumConfig.actionTrackingHandler`
3. Adds method `-updateViewLoadingTime:` to support update loading time for currently active RUM view
---
# 1.5.18-alpha.4
1. Fix: made the SDK's -shutdown method thread-safe
2. Added support for custom RUM View tracking strategy via `FTRumConfig.viewTrackingStrategy`
3. Fix: made `sdk_name` a mandatory baseline field
---
# 1.5.18-alpha.3
1. Fix: missing `#include <string.h>` in tvOS platform
---
# 1.5.18-alpha.2
1. Crash monitor improvements: debug logs added, duplicate/secondary crash protection 
---
# 1.5.18-alpha.1
1. Fix SDK collecting webView data injection UserScripts deleting user-added UserScripts issue
2. Fix Longtask monitoring crash caused by modifying main thread name in sub-thread when getting main thread stack
---
# 1.5.17
1. Add `FTRUMConfig.enableTraceWebView` configuration to enable webView data collection through SDK, control host address filtering through `FTRUMConfig.allowWebViewHost`
2. Add `FTRumConfig.sessionTaskErrorFilter` to filter local network errors
3. Add `FTMobileConfig.remoteConfiguration` to support remote conditional configuration, `FTMobileConfig.remoteConfigMiniUpdateInterval` to set minimum update interval after enabling remote control
---
# 1.5.17-beta.2
1. Same as 1.5.17-beta.1
---
# 1.5.17-beta.1
1. Fix webView unable to collect when `FTRUMConfig.allowWebViewHost` is empty
2. Optimize remote dynamic parameter update logic, add protection code to prevent parsing exceptions caused by parameter type configuration errors
3. Support intercepting SessionTask Error through `FTRUMConfig.sessionTaskErrorFilter`
---
# 1.5.17-alpha.1
1. Add `FTRUMConfig.enableTraceWebView` configuration to enable webView data collection through SDK, control host address filtering through `FTRUMConfig.allowWebViewHost`
2. Add `FTURLSessionDelegate.errorFilter` to filter local network errors
3. Add `FTMobileConfig.remoteConfiguration`, `FTMobileConfig.remoteConfigMiniUpdateInterval` to configure remote configuration and dynamic parameter configuration. `FTMobileAgent` adds `+updateRemoteConfig` and `+ updateRemoteConfigWithMiniUpdateInterval:callback:` remote configuration update request methods
---
# 1.5.16
1. Add `FTMobileConfig.lineDataModifier`, `FTMobileConfig.dataModifier` to support data write replacement and data desensitization
2. Add `FTRUMConfig.sessionErrorSampleRate` to support error sampling, when not sampled by setSamplingRate, can sample RUM data from 1 minute ago when errors occur
3. Logger supports filtering custom log levels through `logLevelFilter`
4. When native page jumps to WebView page, fill view_referrer with native page name
---
# 1.5.16-beta.4
1. Same as 1.5.16-beta.3
---
# 1.5.16-beta.3
1. Logger line data write replacement omission supplement
2. Fix fatal ANR data write failure
---
# 1.5.16-beta.2
1. Same as 1.5.16-beta.1
---
# 1.5.16-beta.1
1. Same as 1.5.15-alpha.1-1.5.15-alpha.6
2. Complete `sessionOnErrorSampleRate` functionality implementation
---
# 1.5.16-alpha.1
1. Same as 1.5.15-alpha.1-1.5.15-alpha.6
2. Adjust RUM error Session sampling logic
3. Logger supports filtering custom log levels through `logLevelFilter`
4. Fix crash error causing redundant invalid action write issues
5. Add `FTMobileConfig.lineDataModifier`, `FTMobileConfig.dataModifier` to support data write replacement, applicable for data desensitization
6. When native page jumps to WebView page, fill view_referrer with native page name
---
# 1.5.15
1. Fix Swift Package Manager compilation error issues
---
# 1.5.15-alpha.6
1. Resolve conflict with `AFNetworking` URLSession resume method swizzle
---
# 1.5.15-alpha.5
1. Change `sessionOnErrorSampleRate` type to `int`. Adjust Error Session collection logic, start collection from 1 minute before error occurs.
---
# 1.5.15-alpha.3
1. Add `sessionOnErrorSampleRate` field to FTRumConfig. If enabled, when errors occur in Sessions not selected by sampling rate, SDK will collect data from these originally uncollected Sessions
---
# 1.5.15-alpha.2
1. Adjust data sync UserAgent format
---
# 1.5.15-alpha.1
1. Fix custom metrics loss when adding RUM Error using `[FTExternalDataManager addErrorWithType:state:message:stack:property:]`
2. Update tvOS environment default `sdk_name` to `df_tvos_rum_sdk`
3. Optimize data sync packageId generation logic
---
# 1.5.14
1. Add RUM `Resource` data fields `resource_first_byte_time`, `resource_dns_time`, `resource_download_time`, `resource_connect_time`, `resource_ssl_time`, `resource_redirect_time`, support optimized display on Guance Cloud and APM flame graph time alignment
2. Enable `FTMobileConfig.enableDataIntegerCompatible` by default
3. Add support to disable SDK internal URLSession Method Swizzling through macro `FT_DISABLE_SWIZZLING_RESOURCE`
4. Optimize data sync, add failure retransmission logic
---
# 1.5.14-beta.3
1. Same as 1.5.14-beta.1
---
# 1.5.14-beta.1
1. Add support to disable SDK internal URLSession Method Swizzling through macro `FT_DISABLE_SWIZZLING_RESOURCE`
2. Optimize data sync link tracing methods
---
# 1.5.14-alpha.1
1. Optimize data sync, add failure retransmission logic
2. Enable `FTMobileConfig.enableDataIntegerCompatible` by default
3. Add RUM Resource data fields `resource_first_byte_time`, `resource_dns_time`, `resource_download_time`, `resource_connect_time`, `resource_ssl_time`, `resource_redirect_time`, optimize display on Guance Cloud and support APM flame graph time alignment
---
# 1.5.13
1. Optimize page collection logic, prevent RUM View collection loss caused by special views
---
# 1.5.13-beta.1
1. Update ViewController viewUUID logic to prevent RUM from adding Views with same view_id
---
# 1.5.13-alpha.3
1. RUM View collection optimization, prevent duplicate View collection
2. RUM View subpage collection logic adjustment, only collect subviews of parent views UITabBarController, UINavigationController, UISplitViewController
---
# 1.5.13-alpha.2
1. tvOS environment class name replacement, fix usage of undeclared class
---
# 1.5.13-alpha.1
1. Optimize page collection logic, prevent view collection loss caused by special views
---
# 1.5.12
1. Adjust file storage path configuration, fix database creation failure issues
2. Updated tvOS environment default `service` and log `source` to `df_rum_tvos` and `df_rum_tvos_log` respectively
3. Fix RUM Action event `duration` calculation inaccuracy
---
# 1.5.12-beta.1
1. Modify tvOS environment default service to `df_rum_tvos`, log source to `df_rum_tvos_log`
2. Fix RUM Action duration error
---
# 1.5.12-alpha.1
1. Modify tvOS environment file storage path, fix inability to create database
---
# 1.5.11
1. RUM Resource collection optimization, prevent RUM Resource automatic collection from collecting SDK internal requests when RUM Resource automatic collection is enabled
2. Fix skyWalking type link tracing failure in Widget Extension
---
# 1.5.11-beta.1
1. RUM Resource collection optimization, prevent RUM Resource automatic collection from collecting SDK internal requests when RUM Resource automatic collection is enabled due to nil task.currentRequest when task.resume() is called
2. Fix skyWalking type link tracing failure in Widget Extension
---
# 1.5.10
1. Support intercepting Request custom Trace through `FTTraceConfig.traceInterceptor`,
    add RUM Resource custom properties through `FTRumConfig.resourcePropertyProvider`
2. Fix dynamic global property method exception in multi-threaded access
3. Optimize WebView passed data information
---
# 1.5.10-beta.3
1. SDK version information content transmission optimization
2. Optimize Resource data processing, prevent multi-threaded use of NSMutableData exception, NSURLResponse forced to NSHTTPURLResponse exception
---
# 1.5.10-beta.2
1. Adjust WebView RUM passed data format
---
# 1.5.10-beta.1
1. `traceInterceptor` and `resourcePropertyProvider` block alias added `FT` prefix, return value NSDictionary added type declaration
2. Fix dynamic global property method multi-threaded access exception
---
# 1.5.10-alpha.1
1. Support global `traceInterceptor` and `resourcePropertyProvider`
---
# 1.5.9
1. Add support for intercepting `URLRequest` through `FTURLSessionDelegate.traceInterceptor` block, perform custom link tracing, change spanId and traceId in the link
2. RUM Resource supports collecting network requests initiated by swift async/await URLSession API
3. Fix LongTask and Anr associated View error
---
# 1.5.9-beta.3
1. Fix LongTask and Anr associated View error
---
# 1.5.9-beta.2
1. Fix Resource collection filtering SDK internal URL issues
2. Fix swift package compilation configuration errors
---
# 1.5.9-beta.1
1. Same as 1.5.9-alpha.1
---
# 1.5.9-alpha.1
1. Add custom Trace association RUM
2. Support collecting Resource data initiated by swift async/await URLSession API
---
# 1.5.8
1. Add tvOS support
2. Add RUM item limit function, support limiting SDK maximum cache item data through `FTRUMConfig.rumCacheLimitCount`, support specifying discard new data or old data through `FTRUMConfig.rumDiscardType`
3. Add support for limiting total cache size through `FTMobileConfig.enableLimitWithDbSize`, after enabling
   `FTLoggerConfig.logCacheLimitCount` and `FTRUMConfig.rumCacheLimitCount` will be invalid,
   support setting db discard strategy through `FTMobileConfig.dbDiscardType`,
   support setting db cache limit size through `FTMobileConfig.dbCacheLimit`
4. Add configuration information debug log output
---
# 1.5.8-beta.2
1. Same as 1.5.8-beta.1
---
# 1.5.8-beta.1
1. db total cache size optimization
2. `FTRUMConfig.rumCacheLimitCount` default value changed to 100_1000
---
# 1.5.8-alpha.2
1. Add tvOS support
2. Add support for enabling db size limit through `FTMobileConfig.enableLimitWithDbSize`,
    support setting db discard strategy through `FTMobileConfig.dbDiscardType`,
    support setting db cache limit size through `FTMobileConfig.dbCacheLimit`
3. Add configuration information debug log output
---
# 1.5.8-alpha.1
1. Add RUM item limit function, support limiting SDK maximum cache item data through `FTRUMConfig.rumCacheLimitCount`, support specifying discard new data or old data through `FTRUMConfig.rumDiscardType`
---
# 1.5.7
1. Support setting `FTRUMConfig.freezeDurationMs` for card detection threshold
2. Optimize SDK `shutDown` method to avoid carding or WatchDog crash caused by synchronous waiting on the main thread
---
# 1.5.7-beta.1
1. Same as 1.5.7-alpha.1, 1.5.7-alpha.2
---
# 1.5.7-alpha.2
1. Replace longtask detection time range setting parameter `blockDurationMs` with `freezeDurationMs`
---
# 1.5.7-alpha.1
1. Add method to set longtask detection time range
2. Optimize SDK `shutDown` method to avoid carding or WatchDog crash caused by synchronous waiting on the main thread
---
# 1.5.6
1. Support `FTMobileConfig.compressIntakeRequests` for synchronous data deflation configuration
2. RUM adds `addAction:actionType:property` and `startAction:actionType:property:` methods, optimize RUM Action collection logic
3. Fix crash caused by NSFileHandle deprecated API
---
# 1.5.6-beta.1
1. Same as 1.5.5-alpha.1
2. Fix crash caused by NSFileHandle deprecated API

---
# 1.5.5
1. Fix crash caused by array out of bounds in `FTResourceMetricsModel`
---
# 1.5.5-beta.1
1. Same as 1.5.2-hotfix.2
---
# 1.5.5-alpha.1
1. Add support for compressing SDK internal data requests
2. RUM adds `addAction:actionType:property` and `startAction:actionType:property:` methods, optimize RUM Action collection logic
---
# 1.5.4
1. Add global, log, RUM globalContext property dynamic setting method
2. Add clear data method, support deleting all data not yet uploaded to the server
3. Adjust maximum interval for synchronous intermittent support to 5000 milliseconds
---
# 1.5.4-beta.1
1. Same as 1.5.4-alpha.1-1.5.4-alpha.4
2. SDK `shutDown` method internal close order adjustment
3. RUM `addError` method parameter `stack` allows null
---
# 1.5.4-alpha.4
1. Adjust maximum interval for synchronous intermittent support to 5000 milliseconds
2. Global, log, RUM globalContext property dynamic setting method modified to class method
3. Abandon `FTMobileConfig.version` property
4. Optimize dynamic tags assignment timing
---
# 1.5.4-alpha.3
1. Add clear data method, support deleting all data not yet uploaded to the server
2. Optimize SDK `shutDown` method, changed from instance method to class method to prevent test environment assertion error
3. Adjust maximum interval for synchronous intermittent support to 500 milliseconds
4. Supplement internal error prompt log
---
# 1.5.4-alpha.2
1. Optimize dynamic tags assignment timing
---
# 1.5.4-alpha.1
1. Add global, log, RUM globalContext property dynamic setting method
---
# 1.5.3
1. Fix crash caused by improper attribute modifier memory access
2. Use internal warning log instead of method signature verification assertion in `FTSwizzler`
3. Optimize decimal precision of collected data
---
# 1.5.2-hotfix.2
1. Fix crash caused by array out of bounds in `FTResourceMetricsModel`
---
# 1.5.2
1. Fix Xcode 16 compilation missing `#include <arm/_mcontext.h>` header file issue
2. Filter out Resource directly obtained from local cache or of unknown type when auto-collecting RUM-Resource, prevent duplicate collection
3. Fix UITabBarController subview loadingTime calculation logic
---
# 1.5.2-beta.1
1. Same as 1.5.2-alpha.1 - 1.5.2-alpha.3
2. Fix UITabBarController subview loadingTime calculation logic
---
# 1.5.2-alpha.3
1. Fix Xcode 16 compilation missing `#include <arm/_mcontext.h>` header file issue
---
# 1.5.2-alpha.2
1. Increase filter condition for auto-collecting RUM-Resource, filter out Resource of unknown resource type
---
# 1.5.2-alpha.1
1. Filter out Resource directly obtained from local cache when auto-collecting RUM-Resource, prevent duplicate collection
---
# 1.5.1
1. Fix line protocol data escape algorithm, solve data synchronization failure due to line break
2. Optimize error type `network_error` error message, unify English description of network request error code
3. Optimize data sync logic, fix crash caused by releasing `uploadDelayTimer` in multi-threaded access
4. Fix crash caused by incorrect encoding format when converting OC string to C string during crash information collection
---

# 1.5.1-beta.2
1. Optimize data sync logic, fix crash caused by releasing `uploadDelayTimer` in multi-threaded access
2. Fix crash caused by incorrect encoding format when converting OC string to C string during crash information collection
---
# 1.5.1-beta.1
1. Same as 1.5.1-alpha.1, 1.5.1-alpha.2
---
# 1.5.1-alpha.2
1. Optimize error type `network_error` error message, unify English description of network request error code
---
# 1.5.1-alpha.1
1. Fix line protocol data escape algorithm, solve data synchronization failure due to line break
---
# 1.5.0
1. RUM resource network request adds remote ip address parsing function
2. Add line protocol Integer data compatible mode, handle web data type conflict issues
3. Log adds custom status method
4. Log data writing optimization, data sync optimization
5. Format parameters of NSDictionary type passed to SDK to prevent data loss due to json conversion failure
---
# 1.5.0-beta.1
1. Same as 1.5.0-alpha.2
---
# 1.5.0-alpha.2
1. Fix mutex lock not initialized during log data writing, causing access conflict
2. Optimize logic for incorrectly formatted error data
3. sdk_data_id algorithm modified
4. Format parameters of NSDictionary type passed to SDK to prevent data loss due to json conversion failure
---
# 1.5.0-alpha.1
1. RUM resource network request adds remote ip address parsing function
2. Add line protocol Integer data compatible mode, handle web data type conflict issues
3. Log adds custom status method
4. Log data writing optimization, data sync optimization
---
# 1.4.14
1. Fix crash caused by accessing destroyed Class object in `FTSwizzler`
2. Fix data consistency and operation conflict issues when NSDictionary type parameters passed to SDK are actually mutable objects
---

# 1.4.14-beta.1
1. Same as 1.4.14-alpha.2
---
# 1.4.14-alpha.2
1. Fix conflict issues when variable properties are passed in
---
# 1.4.14-alpha.1
1. Fix swizzle method conflict with other library swizzle methods

---
# 1.4.13
1. RUM LongTask, Anr collection optimization, fix LongTask stack information collection inaccuracy, support fatal card collection
2. Fix crash caused by multi-threaded operation of NSMutableSet in `FTSwizzler`
3. Fix version information missing in SDK Framework info.plist
4. Fix performance metrics collection failure for Resource when custom NSURLSession is not set delegate
5. SDK internal log conversion to file function optimization, add method to specify file path

---
# 1.4.13-beta.1
1. LongTask, Anr collection optimization, file operation added thread protection
2. Fix NSURLSession metrics collection failure when delegate is not set
3. SDK internal log conversion to file backup file name assignment error fix

---
# 1.4.13-alpha.1
1. LongTask, Anr collection optimization, fix LongTask stack information inaccuracy
2. Fix multi-threaded access causing Resource data swizzle crash
3. Framework info.plist version information supplement
4. sdk_data_id algorithm modified
5. SDK internal log conversion to file function optimization, add method to specify file path

---
# 1.4.12
1. Fix memory leak caused by SDK call shutDown method
2. Fix crash caused by conflict with other libraries when collecting RUM-Resource
3. Fix UncaughtExceptionHandler not passed problem
4. Fix data anomalies caused by multiple SDK initializations

---
# 1.4.12-beta.1
1. Fix memory leak caused by shutDown SDK
2. Fix crash caused by conflict with other libraries when collecting RUM-Resource
3. Process UncaughtException and pass UncaughtExceptionHandler
4. Fix data anomalies caused by duplicate SDK configuration

---
# 1.4.12-alpha.1
1. Data sync, log writing optimization
2. Framework info.plist version information supplement
3. sdk_data_id algorithm modified
---

# 1.4.11
1. Add support for data sync parameter configuration, request item data, sync intermittent time, and log cache item count
2. Add internal log conversion to file method
3. Log associated RUM data acquisition error fix
4. Time-consuming operation optimization
5. Fix crash caused by WebView jsBridge, change WebView reference to weak reference
---

# 1.4.11-beta.1
1. Fix crash caused by WebView jsBridge, change WebView reference to weak reference
---
# 1.4.11-alpha.2
1. Timeout setting for data sync ineffective fix
2. Avoid symbol conflict method name modification
2. Debug log output format optimization
---

# 1.4.11-alpha.1
1. Add support for data sync parameter configuration, request item data, sync intermittent time, and log cache item count
2. Add internal log conversion to file method
3. Log associated RUM data acquisition error fix
4. Time-consuming operation optimization

---
# 1.4.10-beta.2
1. Fix data sync failure

---
# 1.4.10-beta.1
1. Same as 1.4.10-alpha.1-1.4.10-alpha.2
2. Adjust privacy policy reference

---
# 1.4.10-alpha.2
1. Fix data sync failure
2. Fix multi-threaded access causing Resource data swizzle crash

---
# 1.4.10-alpha.1
1. Add privacy policy

---
# 1.4.9-beta.5
1. WebView passed data time precision adaptation

---
# 1.4.9-beta.4
1. Same as 1.4.9-alpha.7, .c file header file reference adjustment

---
# 1.4.9-alpha.7
1. Supplement missing header files, fix compilation failure

---
# 1.4.9-beta.3
1. Use `currentRequest` instead of `originalRequest` when intercepting URLSession data collection, fix data type conversion failure in some scenarios when user customizes RUM-resource rules

---
# 1.4.9-beta.2
1. Optimize RUM-Resource automatic collection logic, fix some collection anomalies
2. Custom priority is higher than automatic tracking when customizing link tracing through `FTURLSessionDelegate`

---
# 1.4.9-beta.1
1. Same as 1.4.9-alpha.1 - 1.4.9-alpha.6
2. longtask, anr occurrence time assignment error fix
3. RUM-Resource automatic collection and `FTURLSessionDelegate` custom collection compatibility handling

---
# 1.4.9-alpha.6
1. WebView passed data time precision adaptation
2. SkyWalking propagation header service parameter adjustment
2. Fix ANR duplicate collection, optimize Error error message, thread backtrace

---
# 1.4.9-alpha.5
1. Add method to get Trace link request header when not associated with RUM
2. BOOL type data format processing modified during data upload

---
# 1.4.9-alpha.4
1. `RUM-View` new metric `view_update_time`

---
# 1.4.9-alpha.3
1. `RUM-View.is_active` page active state modified to metric

---
# 1.4.9-alpha.2
1. `RUM-Action` start event time assignment error fix

---
# 1.4.9-alpha.1
1. Fix arm64e symbol translation failure

---
# 1.4.8-beta.1
1. Same as 1.4.8-alpha.5, debug log output adjustment

---
# 1.4.8-alpha.5
1. Fix `RUM-view.duration` time too long problem
2. RUM-ResourceError `error_type` corresponding value adjusted to `network_error`

---
# 1.4.8-alpha.4
1. Fix crash caused by adding extra parameter SEL when creating IMP in block
2. Fix sampling rate algorithm
3. Optimize debug log output, UUID String format change

---
# 1.4.8-alpha.3
1. Add dataway public network data upload logic
2. Add upload data unique identifier
3. Fix resource duration negative value, resource_first_byte calculation logic modified
4. Auto-collect HTTP Resource logic modified, solve the problem that URLSession cannot be collected when URLSession is created before SDK initialization

---
# 1.4.8-alpha.2
1. RUM Session expiration logic modified, sync reset view, fix RUM-View continuous duration problem caused by HTTP request suspension in APP background
2. Auto-collect HTTP Resource logic modified
3. Add custom HTTP Resource collection function
4. Optimize RUM-ResourceError error message description

---
# 1.4.8-alpha.1
1. Add custom TraceHeader function
2. Set `resourceUrlHandler` in FTRumConfig to replace FTMobileAgent `-isIntakeUrl:` method
3. Fix multiple URLSession resource custom data overwriting issues

---
# 1.4.7-beta.4
1. Data upload logic optimization

---
# 1.4.7-beta.3
1. Data upload logic optimization, prevent stack overflow crash caused by recursion

---
# 1.4.7-beta.2
1. Solve the problem that URLSession is created before SDK and cannot be collected

---
# 1.4.7-beta.1
1. Same as 1.4.7-alpha.2, 1.4.7-alpha.1

---
# 1.4.7-alpha.2
1. RUM LongTask collection optimization
2. RUM Resource supports user-defined resource properties

---
# 1.4.7-alpha.1
1. Solve RUM View timeSpend abnormal problem
2. When View auto-collection is enabled, app Enter background, foreground synchronize view start, stop

---
# 1.4.6-beta.1
1. Same as 1.4.6-alpha.6

---
# 1.4.6-alpha.6
1. Enum naming modified

---
# 1.4.6-alpha.5
1. RUM AddError method adds state parameter
2. User logout method -unbindUser replaced -logout

---
# 1.4.6-alpha.4
1. app Become, Resign Active synchronize view start, stop

---

# 1.4.6-alpha.3
1. FPS calculation error for high-refresh-rate devices fixed

---
# 1.4.6-alpha.2
1. Handle UITabBarController subview loadingTime abnormality

---
# 1.4.6-alpha.1
1. Data upload handles empty value data logic modification

---
# 1.4.5-beta.1
1. Fix RUM View time assignment error

---
# 1.4.5-alpha.1

1. Webview RUM data format adjustment

---
# 1.4.4-beta.1
1. Custom log printing console format adjustment

---
# 1.4.4-alpha.1
1. Remove log auto-collection function, add custom log printing console switch
2. Add custom env

---
# 1.4.3-beta.1
1. Same as 1.4.3-alpha.1

---

# 1.4.3-alpha.1
1. Fix RUM data loss
2. RUM resource, error, long_task missing action related fields supplement

---

# 1.4.2-alpha.3
1. FTSDKCore basic library supports custom database path and name

---
# 1.4.2-alpha.2
1. Delete dataKitUUID

---
# 1.4.2-alpha.1
1. Solve package without module problem
2. Fix known BUG

---
# 1.4.1-alpha.3
1. Fix RUM resource data format error

---
# 1.4.1-alpha.2
1. RUM resource resource_type assignment modified

---
# 1.4.1-alpha.1
1. Fix RUM resource processing response header without considering case-insensitive compatibility

---

# 1.4.0-beta.3
1. Add SDK shutDown API

---
# 1.4.0-beta.2
1. podspec source_files adjustment, solve duplicate warning caused by soft link file

---
# 1.4.0-beta.1
1. Add Widget Extension data collection function
2. Network link tracing auto-tracking optimization
3. Add SPM support, add support for carthage packaging FTMobileExtension
4. Fix known BUG

---
# 1.3.12-alpha.4
1. macos error monitoring supports collecting device power usage rate

---
# 1.3.12-alpha.3
1. Project structure adjustment, FTSDKCore supports macOS

---
# 1.3.12-alpha.2
1. Package structure adjustment, sdk supports platform version modification

---
# 1.3.12-alpha.1
1. Package structure adjustment, basic functions support macOS

---
# 1.3.11-alpha.1
1. Fix known BUG
2. NSURLProtocol protocolClasses setting optimization
3. Add SPM support, add support for carthage packaging FTMobileExtension

---
# 1.3.10-beta.3
1. Fix memory leak
2. Fix other known BUG

---
# 1.3.10-alpha.7
1. Fix memory leak caused by multi-threaded arraycopy
2. Fix known BUG

---
# 1.3.10-alpha.6
1. Fix memory leak caused by log collection
2. SDK supports version modification, iOS supports 10.0+, macOS supports 10.13+

---
# 1.3.10-beta.2
1. Fix Error monitoring attribute field error

---

# 1.3.10-beta.1
1. Add intakeUrl Resource filtering method
2. Resource,Action,View,Error,LongTask,Logger support adding extension parameters
3. config service parameter adjustment
4. Fix known BUG

---

# 1.3.10-alpha.3
1. config service parameter adjustment
2. Fix startup duration statistics anomaly caused by switching from application to APP
3. Action Type adds launch_warm adaptation for iOS15, which is warmed up before APP startup
4. Fix dispatch_semaphore_t priority inversion

---
# 1.3.10-alpha.1
1. Add intakeUrl Resource filtering method
2. Resource,Action,View,Error,LongTask,Logger support adding extension parameters

---
# 1.3.8-beta.4
1. Modify DDtrace Header Propagation rules

---

# 1.3.8-beta.3
1. File reference format fix

---

# 1.3.8-beta.2
1. Fix GMT time modification causing global timezone issue
2. Internal data upload URLSession uses custom session instead of sharedSession

---
# 1.3.8-beta.1
1. External RUM supplement custom actionType method
2. Add iPhone14 device information adaptation
3. Add active_pre_warm to determine if startup is pre-warmed

---
# 1.3.8-alpha.3
1. Test case modification
---

# 1.3.8-alpha.2
1. Add iPhone14 device information adaptation
2. Add active_pre_warm to determine if startup is pre-warmed

---

# 1.3.8-alpha.1
1. External RUM supplement custom actionType method

---

# 1.3.7-beta.1
1. User binding data extension
2. Crash log symbolization

---

# 1.3.7-alpha.4
1. FTDeviceMetricsMonitorType type value adaptation

---

# 1.3.7-alpha.4
1. userLogout user email cache cleanup

---
# 1.3.7-alpha.3
1. Solve potential cold start event omission

---

# 1.3.7-alpha.2
1. User binding data extension
2. import reference error adjustment

---
# 1.3.7-alpha.1
1. User binding data extension

---
# 1.3.6-beta.2
1. Solve potential data omission during startup

---
# 1.3.6-beta.1
1. Configure monitoring items, collect fps, memory, cpu related data
2. Crash log, card log collection content format adjustment

---

# 1.3.6-alpha.4
1. Supplement public header files

---

# 1.3.6-alpha.3
1. cpu collection field name modified, cpu data assignment error modified

---

# 1.3.6-alpha.2
1. cpu collection rules modified

---

# 1.3.6-alpha.1
1. Configure monitoring items, collect fps, memory, cpu related data
2. Crash log, card log format adjustment, missing information supplement

---

# 1.3.5-beta.4
1. Solve action duplicate write problem caused by resource error.

---

# 1.3.5-beta.3
1. Solve data upload failure caused by empty string in data.

---

# 1.3.5-beta.2
1. Solve launch event collection error in flutter, reactNative.

---

# 1.3.5-beta.1
1. Correct use of kvo causing hook failure to affect project normal process.
2. Filter out format error data.
3. SDK internal URL filter bug fix.

---

# 1.3.5-alpha.4
1. SDK internal URL filter bug fix.

---
# 1.3.5-alpha.3
1. Filter out format error data.
2. SDK internal log using os_log instead of NSLog.

---
# 1.3.5-alpha.2
1. SDK internal NSLog deletion.

___
# 1.3.5-alpha.1
1. Solve use of kvo causing hook failure to affect project normal process.

___
# 1.3.4-beta.2
1. Supplement static library public header files missing
2. FTMobileSDK scheme shared

___

# 1.3.4-beta.1
1. Improve test case coverage

---

# 1.3.4-alpha.3
1. Add onCreateView method to record view loading duration

___
# 1.3.4-alpha.2
1. Modify launch event calculation rules

2. RUM page viewReferrer recording rules modified

___
# 1.3.4-alpha.1
1. Modify launch event calculation rules

2. RUM page viewReferrer recording rules modified

___
# 1.3.3-alpha.5
1. trace enableAutoTrace error fix

___
# 1.3.3-alpha.4
1. DDtrace header modified

___
# 1.3.3-alpha.3
1. NetworkTraceType default to DDtrace, DDtrace traceid algorithm modified

2. External RUM api adjustment

___
# 1.3.3-alpha.2
1. Support Skywalking, W3c TraceParent,

2. Zipkin adds single header support

3. External RUM api adjustment

___

# 1.3.3-alpha.1
1. Support Skywalking, W3c TraceParent,

2. Zipkin adds single header support

___

# 1.3.2-alpha.1
1. Add setGlobalTag method.

___

# 1.3.1-alpha.11
1. Fix bug in multi-threaded access to common properties

___
# 1.3.1-alpha.10
1. Modify RUM string data length to 0 error
2. rum constant usage adjustment

___
# 1.3.1-alpha.9
1. RUM, Trace data organization, provide external call API
2. Fix RUM data errors

---

# 1.3.1-alpha.8
1. RUM, Trace data organization, provide external call API

---
# 1.3.1-alpha.7
1. RUM, Trace data organization, provide external call API
2. RUM Config adds enableTraceUserResource method

---
# 1.3.1-alpha.6
1. RUM, Trace data organization, provide external call API

---
# 1.2.8-alpha.7
1. unused code organization

2. RUM, Trace data processing methods adjusted

---
# 1.2.8-alpha.4
1. unused code organization

2. RUM, Trace data processing methods adjusted

---
# 1.2.8-alpha.3
1. unused code organization

2. RUM, Trace data processing methods adjusted

---
# 1.2.8-alpha.2
1. unused code organization

2. RUM data processing methods adjusted

---
# 1.2.8-alpha.1
1. unused code organization

2. RUM data processing methods adjusted

---
# 1.2.7-alpha.3
1. RUM view data collection, parameter viewController passed as nil bug fix

2. Trace ID algorithm correction

---
# 1.2.7-alpha.1
1. RUM view data collection, parameter viewController passed as nil bug fix

---
# 1.2.6-alpha.2
1. RUM user-defined global tag function added

2. Fix IP address bug

---
# 1.2.6-alpha.1
1. RUM user-defined global tag function added

---
# 1.2.5-alpha.2
1. Log discard strategy added

2. APP lifecycle monitoring optimization

3. UISegmentedControl click event collection bug fix

4. Page load duration bug fix

5. Fix IP address bug

---
# 1.2.5-alpha.1
1. Log discard strategy added

2. APP lifecycle monitoring optimization

3. UISegmentedControl click event collection bug fix

4. Page load duration bug fix

---
# 1.2.4-alpha.2
1. Fix crash problem appearing on iOS14.5+ devices

---
# 1.2.3-alpha.1
1. Multi-threaded lazy loading BUG fix

---
# 1.2.2-alpha.1
1. logger add filter condition

---
# 1.2.1-alpha.7
1. Extract common methods, set sub-package

2. podspec modification compatible with osx, header file reference modification

---
# 1.2.1-alpha.6
1. Extract common methods, set sub-package

2. podspec modification compatible with osx, header file reference modification

---
# 1.2.1-alpha.5
1. Extract common methods, set sub-package

2. podspec syntax error, sub-package removes header file referencing the main package

---
# 1.2.1-alpha.4
1. Extract common methods, set sub-package
2. podspec syntax error, sub-package removes header file referencing the main package

---
# 1.2.1-alpha.3
1. Extract common methods, set sub-package
2. podspec syntax error

---
# 1.2.1-alpha.2
1. Extract common methods, set sub-package

---
# 1.2.1-alpha.1
1. swizzle method modified

---

# 1.2.0-alpha.5
1. Config configuration modified

2. Logger and Trace data support binding RUM

---
# 1.2.0-alpha.4
1. Config configuration modified

2. Logger and Trace data support binding RUM

---
# 1.2.0-alpha.3
1. Config configuration modified

2. Logger and Trace data support binding RUM

---
# 1.2.0-alpha.2
1. Config configuration modified
2. Logger and Trace data support binding RUM

---
# 1.2.0-alpha.1
1. Config configuration modified
2. Logger and Trace data support binding RUM

---

# 1.1.0-alpha.10
1. RUM data adjustment
2. Test case added

---
# 1.1.0-alpha.9
1. RUM data adjustment
2. Test case added

---
# 1.1.0-alpha.8
1. RUM data adjustment
2. Test case added

---
# 1.1.0-alpha.7
1. RUM data adjustment
2. Test case added

---
# 1.1.0-alpha.6
1. RUM data adjustment
2. resource_size added response header size

---
# 1.1.0-alpha.5
1. RUM data adjustment

---
# 1.1.0-alpha.4
1. RUM data adjustment

---
# 1.1.0-alpha.3
1. RUM data adjustment

---
# 1.1.0-alpha.2
1. RUM data adjustment

---
# 1.1.0-alpha.1
1. RUM data adjustment

---

# 1.0.4-alpha.9
1. Add escape character processing for tag, field, measurement values

---
# 1.0.4-alpha.8
1. Fix time unit microsecond, nanosecond usage errors
2. Fix int overflow issues

---
# 1.0.4-alpha.7
1. Fix time unit microsecond, nanosecond usage errors

---
# 1.0.4-alpha.6
1. Network link data collection and reporting

---

# 1.0.4-alpha.5
1. RUM data collection
2. Stutter, ANR collection

---
# 1.0.4-alpha.4
1. RUM data collection
2. Stutter, ANR collection
3. Config configuration for enabling UIBlock, ANR collection

---

# 1.0.4-alpha.2
1. Network error rate, time overhead collection
2. Stutter, ANR collection
3. Config configuration for enabling UIBlock, ANR collection

---
# 1.0.4-alpha.1
1. Network error rate, time overhead collection
2. Stutter, ANR collection

---
# 1.0.3-beta.2
1. Fix various error issues, release stable version

---

# 1.0.3-beta.1
1. Fix errors, improve performance

---

# 1.0.3-alpha.11
1. Batch log writing to database
2. Log __content size limit

---

# 1.0.3-alpha.10
1. Adjust sampling rate to network request information collection sampling rate
2. Use XML files to set page description and view tree description

---

# 1.0.3-alpha.9
1. Response parsing modifications
2. Add new fields to logging type

---

# 1.0.3-alpha.8
1. Process body content based on content-type
2. Network trace __content size limit
3. Bug fixes

---
# 1.0.3-alpha.7
1. Process body content based on content-type
2. Network trace __content size limit
3. Bug fixes

---
# 1.0.3-alpha.6
1. Object __name concatenate application bundleID
2. Network trace spanID changed to UUID

---
# 1.0.3-alpha.5
1. Add logging, object, keyevent reporting types
2. Add network information collection link tracing, log collection, event log collection
3. Set NSLog not to print in release, avoid database writing in main thread, modify token request result processing logic

---
# 1.0.3-alpha.4
1. logging, object, keyevent reporting types added
2. Increase network information collection link tracing, log collection, event log collection
3. dSYMUUID acquisition method modified
4. SDK internal log loop bug fix

---
# 1.0.3-alpha.2
1. logging, object, keyevent reporting types added
2. Increase network information collection link tracing, log collection, event log collection
3. dSYMUUID acquisition method modified

---
# 1.0.3-alpha.1
1. logging, object, keyevent reporting types added
2. Increase network information collection link tracing, log collection, event log collection

---
# 1.0.2-alpha.26
1. Add sampling rate
2. Add method to get crash log
3. object, keyevent, logging upload methods added

---
# 1.0.2-alpha.25
1. Modify connected Bluetooth device list

---

# 1.0.2-alpha.24
1. Add intercept https request
2. Connected Bluetooth device key modified

---

# 1.0.2-alpha.23
1. Network speed optimization
2. Monitoring item upload enabled but no monitoring type set
3. Distance sensor distance status acquisition modified

---

# 1.0.2-alpha.22
1. Process flow chart duration i processing
2. page_desc default value modified to N/A

---
# 1.0.2-alpha.21
1. Add UIView category, add attribute to set whether to add descriptionVtp to NSIndexPath in vtp, add descriptionVtp attribute
2. Add switch to determine whether to replace description
3. Add description log switch

---
# 1.0.2-alpha.19
1. vtp_desc, page_desc field added
2. addVtpDescDict, addPageDescDict methods added
3. Header file reference error fix

---
# 1.0.2-alpha.17
1. vtp changed to tag vtp_id changed to field
2. UITabBar click event without vtp adjustment

---
# 1.0.2-alpha.16
1. Add vtp_id tag

---
# 1.0.2-alpha.15
1. Network request error rate acquisition failure fix

---
# 1.0.2-alpha.12
1. Add method to set monitoring item type for monitoring item cycle upload
2. autotrack click event filtering method modified

---

# 1.0.2-alpha.11
1. Remove product
2. Change event_id from field to tag
3. Adjust some tag names

---

# 1.0.2-alpha.5
1. Change latitude, longitude from tag to field
2. Set location update distance to 200 meters

---

# 1.0.2-alpha.4
1. Change vtp from tag to field
2. Add event_id
3. Fix flow chart flowId initialization bug

---
# 1.0.2-alpha.1
1. Extend monitoring items
2. Product setting, corresponding to full tracking, flow chart, monitoring item upload metric names

---
# 1.0.1-alpha.22
1. Fix method name spelling errors
2. Fix blacklist/whitelist judgment logic

---
# 1.0.1-alpha.21
1. trackImmediate and trackImmediateList methods main thread callback
2. CLLocationManagerDelegate callback logic processing

---
# 1.0.1-alpha.20
1. Optimize data storage structure, optimize network upload module
2. Optimize log printing, optimize full tracking
3. Add startLocation method to Agent

---
# 1.0.1-alpha.19
1. Fix page flow chart metric set name validation
2. Location information - municipality province city consistency

---
# 1.0.1-alpha.18
1. Add validation for page flow chart metric set names
2. Fix error code spelling errors
3. Fix parameter concatenation bug during upload

---
# 1.0.1-alpha.17
1. Fix application name acquisition bug

---
# 1.0.1-alpha.16
1. Fix SDK unable to get version number issue
2. Change real-time monitoring items from tag to field, remove flow chart device tag data

---

# 1.0.1-alpha.15
1. Optimize network framework parameters concatenation method
2. Fix network speed acquisition bug
3. Add country to Location

---
# 1.0.1
1. Report flow chart

---
# 1.0.0

1. User custom tracking
2. FT Gateway data synchronization

