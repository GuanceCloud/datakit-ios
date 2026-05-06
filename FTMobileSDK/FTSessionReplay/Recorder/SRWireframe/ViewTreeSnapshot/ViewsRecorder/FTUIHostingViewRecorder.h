//
//  FTUIHostingViewRecorder.h
//  FTMobileSDK
//
//  Created by OpenAI on 2026/4/29.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes;

NS_ASSUME_NONNULL_BEGIN

@interface FTUIHostingViewBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, copy) NSString *placeholderLabel;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, copy, nullable) NSArray<FTSRWireframe *> *wireframes;
@end

@interface FTUIHostingViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

- (instancetype)initWithIdentifier:(NSString *)identifier;
+ (BOOL)isSwiftUIHostingView:(UIView *)view;
+ (BOOL)isSwiftUIGraphicsView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
