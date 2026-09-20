//
//  FTElectronWebViewDescriptor.h
//  GuanceElectronWebView
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

#if TARGET_OS_OSX
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FTBindInfo;

@interface FTElectronWebViewDescriptor : NSObject
@property (nonatomic, assign) int64_t webContentsID;
@property (nonatomic, assign) int64_t slotID;
@property (nonatomic, assign, getter=isStandalone) BOOL standalone;
@property (nonatomic, weak, nullable) NSView *hostView;
@property (nonatomic, weak, nullable) NSView *matchedNativeView;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) BOOL webContentsVisible;
@property (nonatomic, assign) BOOL nativeViewVisible;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, assign) BOOL requiresFullSnapshot;
@property (nonatomic, assign) NSInteger zIndex;
@property (nonatomic, strong) FTBindInfo *bindInfo;
@end

NS_ASSUME_NONNULL_END

#endif
