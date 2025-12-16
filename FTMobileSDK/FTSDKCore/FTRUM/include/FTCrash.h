//
//  FTCrashMonitor.h
//
//  Created by hulilei on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"
#import "FTCrashMonitorType.h"

NS_ASSUME_NONNULL_BEGIN

/// Crash collection tool
@interface FTCrash : NSObject


@property (nonatomic, readwrite, assign) FTCrashMonitorType monitoring;


@property (nonatomic, readonly, strong) id<FTBacktraceReporting> backtraceReporting;


@property(nonatomic, readwrite, strong, nullable) NSDictionary<NSString *, id> *userInfo;

/** The maximum number of reports allowed on disk before old ones get deleted.
 *
 * Default: 1
 */
@property (nonatomic, readwrite, assign) int maxReportCount;

/// When enabled, the SDK reports SIGTERM signals to Sentry.
///
/// It's crucial for developers to understand that the OS sends a SIGTERM to their app as a prelude
/// to a graceful shutdown, before resorting to a SIGKILL. This SIGKILL, which your app can't catch
/// or ignore, is a direct order to terminate your app's process immediately. Developers should be
/// aware that their app can receive a SIGTERM in various scenarios, such as  CPU or disk overuse,
/// watchdog terminations, or when the OS updates your app.
///
/// @note The default value is NO.
@property (nonatomic, readwrite, assign) BOOL enableSigtermReporting;

/** If true, the application crashed on the previous launch. */
@property(nonatomic, readonly, assign) BOOL crashedLastLaunch;

/** If value > 0, the application crashed on the previous launch. */
@property(nonatomic, readonly, assign) double crashedLastTimestamp;

/// Singleton
+ (instancetype)shared;

- (void)install;
/// Add delegate object for handling error data
/// - Parameter delegate: delegate object
- (void)addErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
/// Remove delegate object for handling error data
/// - Parameter delegate: delegate object
- (void)removeErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
