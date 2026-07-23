//
//  FTIssueDataProvider.h
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stable high-level category for an automatically collected issue.
typedef NS_ENUM(NSUInteger, FTIssueCategory) {
    /// A fatal application crash.
    FTIssueCategoryCrash,
    /// An application-not-responding issue.
    FTIssueCategoryANR,
};

/// Immutable facts describing an automatically collected Crash or ANR.
///
/// The SDK creates this object immediately before constructing the related RUM
/// Error. For historical issues, incident facts come from persisted data while
/// application state read by the Provider belongs to the current process.
@interface FTIssueInfo : NSObject

/// Stable high-level issue category.
@property (nonatomic, assign, readonly) FTIssueCategory category;
/// Error type used by the related RUM Error, such as `ios_crash` or `anr_error`.
@property (nonatomic, copy, readonly) NSString *errorType;
/// Error message when one is available.
@property (nonatomic, copy, nullable, readonly) NSString *message;
/// Captured issue stack.
@property (nonatomic, copy, readonly) NSString *stack;
/// Time when the issue occurred, in nanoseconds since the Unix epoch.
@property (nonatomic, assign, readonly) long long occurredAtNanoseconds;
/// Application state used by the related RUM Error.
@property (nonatomic, copy, readonly) NSString *appState;
/// Issue thread name when the persisted or captured data provides one.
@property (nonatomic, copy, nullable, readonly) NSString *threadName;
/// Whether the issue was reconstructed from persisted data.
@property (nonatomic, assign, readonly, getter=isHistorical) BOOL historical;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

/// Synchronously supplies custom fields for an automatically collected issue.
///
/// The callback may run concurrently, reentrantly, and on any SDK processing
/// thread. It must be thread-safe, must not throw or terminate the process, and
/// should finish within 10 ms. Avoid UI, network, disk, dispatch waits, thread
/// switches, and long lock waits.
///
/// Return `nil` or an empty dictionary to add no fields. The SDK accepts at most
/// 32 non-reserved fields whose keys and values satisfy the documented limits.
typedef NSDictionary<NSString *, id> * _Nullable (^FTIssueDataProvider)(FTIssueInfo *issue);

NS_ASSUME_NONNULL_END
