//
//  FTUIHostingViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/4/29.
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
@property (nonatomic, strong, nullable) id recordingBuilder;
@property (nonatomic, strong, nullable) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

@interface FTUIHostingViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
@property (nonatomic, copy) FTTextObfuscator textObfuscator;

- (instancetype)initWithIdentifier:(NSString *)identifier;
- (instancetype)initWithIdentifier:(NSString *)identifier
                 semanticsOverride:(nullable SemanticsOverride)semanticsOverride
                     textObfuscator:(nullable FTTextObfuscator)textObfuscator;
+ (BOOL)isSwiftUIGraphicsView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
