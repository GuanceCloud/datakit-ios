//
//  FTUIHostingViewRecorder.m
//  FTMobileSDK
//
//  Created by OpenAI on 2026/4/29.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTUIHostingViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"

typedef NS_ENUM(NSInteger, FTSwiftUIWireframePayloadKind) {
    FTSwiftUIWireframePayloadKindShape = 0,
    FTSwiftUIWireframePayloadKindText = 1,
    FTSwiftUIWireframePayloadKindImage = 2,
    FTSwiftUIWireframePayloadKindPlaceholder = 3,
};

@interface FTSwiftUIDataResource : NSObject<FTSRResource>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSData *data;
- (instancetype)initWithIdentifier:(NSString *)identifier mimeType:(NSString *)mimeType data:(NSData *)data;
@end

@interface FTUIHostingViewRecorder()
@property (nonatomic, strong) id reflectionBridge;
@end

@implementation FTUIHostingViewRecorder

- (instancetype)init {
    return [self initWithIdentifier:[NSUUID UUID].UUIDString];
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = identifier;
        if (@available(iOS 13.0, *)) {
            Class bridgeClass = NSClassFromString(@"FTSwiftUIReflectionBridge");
            if (!bridgeClass) {
                bridgeClass = NSClassFromString(@"FTSessionReplay.FTSwiftUIReflectionBridge");
            }
            _reflectionBridge = bridgeClass ? [bridgeClass new] : nil;
        }
    }
    return self;
}

- (FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context {
    if ([FTUIHostingViewRecorder isSwiftUIGraphicsView:view]) {
        return [[FTIgnoredElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    }
    if (![FTUIHostingViewRecorder isSwiftUIHostingView:view]) {
        return nil;
    }
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }

    if (@available(iOS 13.0, *)) {
        int64_t wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
        UIColor *borderColor = attributes.layerBorderColor ? [UIColor colorWithCGColor:attributes.layerBorderColor] : nil;
        id recordingResult = [self recordHostingView:view
                                               frame:attributes.frame
                                                clip:attributes.clip
                                               alpha:attributes.alpha
                                     backgroundColor:attributes.backgroundColor
                                         borderColor:borderColor
                                         borderWidth:attributes.layerBorderWidth
                                       cornerRadius:attributes.layerCornerRadius
                                        textPrivacy:[attributes resolveTextAndInputPrivacyLevel:context.recorder]
                                       imagePrivacy:[attributes resolveImagePrivacyLevel:context.recorder]
                                         wireframeID:wireframeID];
        if (recordingResult) {
            NSArray<FTSRWireframe *> *wireframes = [self wireframesFromPayloads:[recordingResult valueForKey:@"wireframes"]];
            if (wireframes.count == 0) {
                return nil;
            }
            FTUIHostingViewBuilder *builder = [[FTUIHostingViewBuilder alloc] init];
            builder.wireframeID = wireframeID;
            builder.attributes = attributes;
            builder.wireframes = wireframes;
            FTSpecificElement *element = [[FTSpecificElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
            element.nodes = @[builder];
            element.resources = [self resourcesFromPayloads:[recordingResult valueForKey:@"resources"]];
            return element;
        }
    }

    FTUIHostingViewBuilder *builder = [[FTUIHostingViewBuilder alloc] init];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.attributes = attributes;
    builder.placeholderLabel = attributes.hide ? @"Hidden" : @"SwiftUI";
    FTSpecificElement *element = [[FTSpecificElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}

- (id)recordHostingView:(UIView *)view
                  frame:(CGRect)frame
                   clip:(CGRect)clip
                  alpha:(CGFloat)alpha
        backgroundColor:(UIColor *)backgroundColor
            borderColor:(UIColor *)borderColor
            borderWidth:(CGFloat)borderWidth
          cornerRadius:(CGFloat)cornerRadius
            textPrivacy:(NSInteger)textPrivacy
           imagePrivacy:(NSInteger)imagePrivacy
            wireframeID:(int64_t)wireframeID API_AVAILABLE(ios(13.0)) {
    if (!self.reflectionBridge) {
        return nil;
    }
    SEL selector = @selector(recordHostingView:frame:clip:alpha:backgroundColor:borderColor:borderWidth:cornerRadius:textPrivacy:imagePrivacy:wireframeID:);
    NSMethodSignature *signature = [self.reflectionBridge methodSignatureForSelector:selector];
    if (!signature) {
        return nil;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self.reflectionBridge;
    invocation.selector = selector;
    [invocation setArgument:&view atIndex:2];
    [invocation setArgument:&frame atIndex:3];
    [invocation setArgument:&clip atIndex:4];
    [invocation setArgument:&alpha atIndex:5];
    [invocation setArgument:&backgroundColor atIndex:6];
    [invocation setArgument:&borderColor atIndex:7];
    [invocation setArgument:&borderWidth atIndex:8];
    [invocation setArgument:&cornerRadius atIndex:9];
    [invocation setArgument:&textPrivacy atIndex:10];
    [invocation setArgument:&imagePrivacy atIndex:11];
    [invocation setArgument:&wireframeID atIndex:12];
    [invocation invoke];

    __unsafe_unretained id result = nil;
    [invocation getReturnValue:&result];
    return result;
}

- (NSArray<FTSRWireframe *> *)wireframesFromPayloads:(NSArray<id> *)payloads API_AVAILABLE(ios(13.0)) {
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray arrayWithCapacity:payloads.count];
    for (id payload in payloads) {
        FTSRWireframe *wireframe = [self wireframeFromPayload:payload];
        if (wireframe) {
            [wireframes addObject:wireframe];
        }
    }
    return wireframes;
}

- (NSArray<id<FTSRResource>> *)resourcesFromPayloads:(NSArray<id> *)payloads API_AVAILABLE(ios(13.0)) {
    NSMutableArray<id<FTSRResource>> *resources = [NSMutableArray arrayWithCapacity:payloads.count];
    for (id payload in payloads) {
        NSString *identifier = [payload valueForKey:@"identifier"];
        NSString *mimeType = [payload valueForKey:@"mimeType"];
        NSData *data = [payload valueForKey:@"data"];
        FTSwiftUIDataResource *resource = [[FTSwiftUIDataResource alloc] initWithIdentifier:identifier mimeType:mimeType data:data];
        [resources addObject:resource];
    }
    return resources;
}

- (FTSRWireframe *)wireframeFromPayload:(id)payload API_AVAILABLE(ios(13.0)) {
    NSInteger kind = [[payload valueForKey:@"kind"] integerValue];
    int64_t identifier = [[payload valueForKey:@"identifier"] longLongValue];
    CGRect frame = [[payload valueForKey:@"frame"] CGRectValue];
    CGRect clip = [[payload valueForKey:@"clip"] CGRectValue];
    switch (kind) {
        case FTSwiftUIWireframePayloadKindShape: {
            FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc] initWithIdentifier:identifier
                                                                                     frame:frame
                                                                                      clip:clip
                                                                           backgroundColor:[payload valueForKey:@"backgroundColor"]
                                                                              cornerRadius:[payload valueForKey:@"cornerRadius"]
                                                                                   opacity:[payload valueForKey:@"opacity"]];
            wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
            wireframe.border = [[FTSRShapeBorder alloc] initWithColor:[payload valueForKey:@"borderColor"] width:[[payload valueForKey:@"borderWidth"] doubleValue]];
            return wireframe;
        }
        case FTSwiftUIWireframePayloadKindText: {
            FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc] initWithIdentifier:identifier frame:frame];
            wireframe.text = [payload valueForKey:@"text"] ?: @"";
            wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
            wireframe.border = [[FTSRShapeBorder alloc] initWithColor:[payload valueForKey:@"borderColor"] width:[[payload valueForKey:@"borderWidth"] doubleValue]];
            wireframe.shapeStyle = [[FTSRShapeStyle alloc] initWithBackgroundColor:[payload valueForKey:@"backgroundColor"]
                                                                      cornerRadius:[payload valueForKey:@"cornerRadius"]
                                                                           opacity:[payload valueForKey:@"opacity"]];
            wireframe.textStyle = [[FTSRTextStyle alloc] initWithSize:[[payload valueForKey:@"fontSize"] intValue]
                                                                color:[payload valueForKey:@"textColor"]
                                                               family:nil
                                                       truncationMode:[FTSRUtils getTextStyleTruncationMode:[[payload valueForKey:@"lineBreakMode"] integerValue]]];
            FTSRTextPosition *textPosition = [[FTSRTextPosition alloc] init];
            textPosition.alignment = [[FTAlignment alloc] initWithTextAlignment:[[payload valueForKey:@"textAlignment"] integerValue] vertical:@"top"];
            textPosition.padding = [[FTPadding alloc] initWithLeft:0 top:0 right:0 bottom:0];
            wireframe.textPosition = textPosition;
            return wireframe;
        }
        case FTSwiftUIWireframePayloadKindImage: {
            FTSRImageWireframe *wireframe = [[FTSRImageWireframe alloc] initWithIdentifier:identifier frame:frame];
            wireframe.resourceId = [payload valueForKey:@"resourceIdentifier"];
            wireframe.mimeType = [payload valueForKey:@"mimeType"] ?: @"image/png";
            wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
            return wireframe;
        }
        case FTSwiftUIWireframePayloadKindPlaceholder: {
            FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc] initWithIdentifier:identifier frame:frame label:[payload valueForKey:@"label"]];
            wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
            return wireframe;
        }
        default:
            return nil;
    }
}

+ (BOOL)isSwiftUIHostingView:(UIView *)view {
    NSString *className = NSStringFromClass(view.class);
    return [className containsString:@"_UIHostingView"] || [className containsString:@"UIHostingView"];
}

+ (BOOL)isSwiftUIGraphicsView:(UIView *)view {
    NSString *className = NSStringFromClass(view.class);
    return [className containsString:@"SwiftUI._UIGraphicsView"] || [className containsString:@"_UIGraphicsView"];
}

@end

@implementation FTSwiftUIDataResource

- (instancetype)initWithIdentifier:(NSString *)identifier mimeType:(NSString *)mimeType data:(NSData *)data {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _mimeType = [mimeType copy];
        _data = [data copy];
    }
    return self;
}

- (NSString *)calculateIdentifier {
    return self.identifier;
}

- (NSData *)calculateData {
    return self.data;
}

@end

@implementation FTUIHostingViewBuilder

- (CGRect)wireframeRect {
    return self.attributes.frame;
}

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.wireframes) {
        return self.wireframes;
    }
    FTSRPlaceholderWireframe *placeholder = [[FTSRPlaceholderWireframe alloc] initWithIdentifier:self.wireframeID frame:self.wireframeRect label:self.placeholderLabel];
    placeholder.clip = [[FTSRContentClip alloc] initWithFrame:self.wireframeRect clip:self.attributes.clip];
    return @[placeholder];
}

@end
