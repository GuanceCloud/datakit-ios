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

#if defined(GUANCE_COCOAPODS) && (TARGET_OS_IOS || TARGET_OS_TV)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol FTSwiftUIRUMViewHandling <NSObject>
- (void)notifyOnAppearWithIdentity:(NSString *)identity name:(NSString *)name property:(NSDictionary *)property loadTime:(NSNumber *)loadTime;
- (void)notifyOnDisappearWithIdentity:(NSString *)identity;
@end

@interface FTSwiftUIRUMViewBridge : NSObject
@property (class, nonatomic, weak, nullable) id<FTSwiftUIRUMViewHandling> handler;
@end

@protocol FTSwiftUIRUMActionHandling <NSObject>
- (void)notifySwiftUITapActionWithName:(NSString *)name property:(NSDictionary *)property;
@end

@interface FTSwiftUIRUMActionBridge : NSObject
@property (class, nonatomic, weak, nullable) id<FTSwiftUIRUMActionHandling> handler;
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface FTSwiftUIViewNameExtractor : NSObject
- (nullable NSString *)extractNameFromViewController:(UIViewController *)viewController;
@end

@implementation FTSwiftUIRUMViewBridge

static __weak id<FTSwiftUIRUMViewHandling> ft_swiftUIRUMViewHandler = nil;

+ (id<FTSwiftUIRUMViewHandling>)handler {
    return ft_swiftUIRUMViewHandler;
}

+ (void)setHandler:(id<FTSwiftUIRUMViewHandling>)handler {
    ft_swiftUIRUMViewHandler = handler;
}

@end

@implementation FTSwiftUIRUMActionBridge

static __weak id<FTSwiftUIRUMActionHandling> ft_swiftUIRUMActionHandler = nil;

+ (id<FTSwiftUIRUMActionHandling>)handler {
    return ft_swiftUIRUMActionHandler;
}

+ (void)setHandler:(id<FTSwiftUIRUMActionHandling>)handler {
    ft_swiftUIRUMActionHandler = handler;
}

@end

@implementation FTSwiftUIViewNameExtractor

- (nullable NSString *)extractNameFromViewController:(UIViewController *)viewController API_AVAILABLE(ios(13.0), tvos(13.0)) {
    return nil;
}

@end

#endif
