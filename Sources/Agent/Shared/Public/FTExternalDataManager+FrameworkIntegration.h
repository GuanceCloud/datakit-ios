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

#import "FTExternalDataManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTExternalDataManager (FrameworkIntegration)

/// For framework integrations such as React Native, Flutter and uniapp.
/// Application code should use the standard View APIs.
/// Both values use nanoseconds: loadTime is a monotonic duration, while
/// loadStartEpochNs is the Unix epoch timestamp captured at the actual load start.
/// Bridges receiving milliseconds must convert to integer nanoseconds first.
/// Pass nil when the loading start is unavailable.
- (void)onCreateView:(NSString *)viewName
           loadTime:(NSNumber *)loadTime
   loadStartEpochNs:(nullable NSNumber *)loadStartEpochNs;

/// Framework adapter entry point. Native stops Automatic Views at the background
/// boundary; adapters must not send another background stopView. Adapters own
/// route changes and foreground View starts. Existing name-only APIs stay Manual.
- (void)startViewWithName:(NSString *)viewName
                property:(nullable NSDictionary *)property
            trackingType:(FTRUMViewTrackingType)trackingType;

@end

NS_ASSUME_NONNULL_END
