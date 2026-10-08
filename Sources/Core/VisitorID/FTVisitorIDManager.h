//
//  FTVisitorIDManager.h
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

typedef BOOL (^FTVisitorIDURLMatcher)(NSURL *url);

/// Immutable Visitor ID value captured at an event boundary.
@interface FTVisitorIDSnapshot : NSObject
@property (nonatomic, copy, readonly) NSString *value;
@property (nonatomic, strong, readonly) NSDate *createdAt;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Immutable request snapshot, including the header owned by the policy that created it.
@interface FTVisitorIDRequestSnapshot : FTVisitorIDSnapshot
@property (nonatomic, copy, readonly) NSString *headerName;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Process-wide owner of Visitor ID generation, persistence, expiry, and reset.
@interface FTVisitorIDManager : NSObject

+ (instancetype)sharedInstance;

/// Enables a validated policy. Passing `enabled = NO` clears only in-memory state and
/// never reads or writes Visitor storage.
- (void)configureWithEnabled:(BOOL)enabled
                  headerName:(nullable NSString *)headerName
                         ttl:(NSTimeInterval)ttl
                  urlMatcher:(nullable FTVisitorIDURLMatcher)urlMatcher;

/// Returns the current event-time snapshot, or nil while the feature is disabled.
- (nullable FTVisitorIDSnapshot *)snapshot;

/// Matches the URL before acquiring or generating an ID. A non-match never accesses storage.
- (nullable FTVisitorIDRequestSnapshot *)requestSnapshotForURL:(nullable NSURL *)url;

/// Deletes the persisted record. When enabled, immediately creates a replacement ID.
- (void)reset;

/// Clears in-memory policy and ID state without deleting a valid persisted record.
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
