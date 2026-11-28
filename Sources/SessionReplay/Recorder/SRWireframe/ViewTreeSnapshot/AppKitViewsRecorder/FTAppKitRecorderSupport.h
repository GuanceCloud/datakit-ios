//
//  FTAppKitRecorderSupport.h
//  SessionReplay AppKit views
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

#import <AppKit/AppKit.h>
#import "FTSRNodeWireframesBuilder.h"
#import "FTSessionReplayPlatform.h"

@class FTViewAttributes;
@protocol FTSRTextObfuscatingProtocol;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *FTSRAppKitHexColor(NSColor * _Nullable color,
                                                NSAppearance * _Nullable appearance,
                                                NSString *fallback);

@interface FTNSTextBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy, nullable) NSString *backgroundColor;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) NSTextAlignment alignment;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;
@property (nonatomic, assign) FTSRPlatformEdgeInsets padding;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

NS_ASSUME_NONNULL_END

#endif
