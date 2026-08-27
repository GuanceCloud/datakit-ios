//
//  FTViewControllerSwizzling.h
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

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Internal coordinator for loading-time lifecycle instrumentation.
///
/// The default instance scans the main application image and already-loaded
/// non-system Framework images. Tests may add exact executable image paths,
/// such as an XCTest bundle executable, without broadening production scope.
@interface FTViewControllerSwizzling : NSObject

+ (instancetype)sharedInstance;

- (instancetype)initWithInAppIncludes:(nullable NSArray<NSString *> *)inAppIncludes;
- (instancetype)initWithInAppIncludes:(nullable NSArray<NSString *> *)inAppIncludes
                 scanLoadedFrameworks:(BOOL)scanLoadedFrameworks;
- (void)swizzleLoadedViewControllerClassesWithCompletion:(nullable dispatch_block_t)completion;

@end

NS_ASSUME_NONNULL_END
#endif
