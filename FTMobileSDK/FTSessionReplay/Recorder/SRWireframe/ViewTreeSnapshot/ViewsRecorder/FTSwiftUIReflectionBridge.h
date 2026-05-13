//
//  FTSwiftUIReflectionBridge.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/6.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingAttributes : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect clip;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, strong, nullable) UIColor *backgroundColor;
@property (nonatomic, strong, nullable) UIColor *borderColor;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) NSInteger textPrivacy;
@property (nonatomic, assign) NSInteger imagePrivacy;
@property (nonatomic, assign) int64_t wireframeID;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingResult : NSObject
@property (nonatomic, strong, readonly) NSArray *wireframes;
@property (nonatomic, strong, readonly) NSArray *resources;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRenderer : NSObject
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingBuilder : NSObject
- (nullable FTSwiftUIRecordingResult *)build;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIReflectionBridge : NSObject
- (FTSwiftUIRecordingAttributes *)makeRecordingAttributes;
- (nullable FTSwiftUIRenderer *)rendererForHostingView:(UIView *)view;
- (nullable FTSwiftUIRecordingBuilder *)recordingBuilderForRenderer:(FTSwiftUIRenderer *)renderer attributes:(FTSwiftUIRecordingAttributes *)attributes;
@end

NS_ASSUME_NONNULL_END
