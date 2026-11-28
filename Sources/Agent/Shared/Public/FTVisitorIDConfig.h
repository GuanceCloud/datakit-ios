//
//  FTVisitorIDConfig.h
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

/// Matches a complete HTTP(S) URL. Exceptions are treated as a non-match.
typedef BOOL (^FTVisitorIDURLMatchHandler)(NSURL *url);

/// Opt-in anonymous Visitor ID configuration.
///
/// Assign a valid instance to `FTRumConfig.visitorIDConfig` to enable the feature.
/// The SDK generates the identifier; callers cannot supply an identifier value.
@interface FTVisitorIDConfig : NSObject <NSCopying>

/// Required lowercase custom HTTP header name.
@property (nonatomic, copy, nullable) NSString *header;

/// Positive fixed lifetime in hours. Defaults to 24 and does not slide on access.
@property (nonatomic, assign) NSTimeInterval ttlHours;

/// Adds a complete HTTP(S) URL prefix constrained to the same scheme, host, and port.
- (void)addMatchWithURLPrefix:(NSString *)prefix NS_SWIFT_NAME(addMatch(urlPrefix:));

/// Adds a regular expression searched against the complete URL string.
- (void)addMatchWithRegularExpression:(NSRegularExpression *)regularExpression NS_SWIFT_NAME(addMatch(regularExpression:));

/// Adds a custom URL predicate.
- (void)addMatchWithHandler:(FTVisitorIDURLMatchHandler)handler NS_SWIFT_NAME(addMatch(handler:));

@end

NS_ASSUME_NONNULL_END
