//
//  FTAppKitRecorderSupport.h
//  SessionReplay AppKit views
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
