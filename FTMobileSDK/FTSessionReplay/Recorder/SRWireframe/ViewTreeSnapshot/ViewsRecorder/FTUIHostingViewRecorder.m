//
//  FTUIHostingViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/4/29.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTUIHostingViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSwiftUIReflectionBridge.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSessionReplayCoreImports.h"
#import "FTUIImageResource.h"

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
+ (Class)swiftUIGraphicsViewClass;
@end

@implementation FTUIHostingViewRecorder

- (instancetype)init {
    return [self initWithIdentifier:[NSUUID UUID].UUIDString];
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
    return [self initWithIdentifier:identifier semanticsOverride:nil textObfuscator:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                 semanticsOverride:(SemanticsOverride)semanticsOverride
                     textObfuscator:(FTTextObfuscator)textObfuscator {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _semanticsOverride = semanticsOverride ?: ^FTSRNodeSemantics * _Nullable(UIView *view, FTViewAttributes *attributes) {
            return nil;
        };
        _textObfuscator = textObfuscator ?: ^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext *context, FTViewAttributes *attributes) {
            return [FTSRTextObfuscatingFactory staticTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        };
        if (@available(iOS 13.0, *)) {
            _reflectionBridge = [FTSwiftUIReflectionBridge new];
        }
    }
    return self;
}

- (FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context {
    if ([FTUIHostingViewRecorder isSwiftUIGraphicsView:view]) {
        return [[FTIgnoredElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    }

    if (@available(iOS 13.0, *)) {
        int64_t wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];

        FTSwiftUIRenderer *renderer = [self rendererForHostingView:view];
        if (renderer) {
            if (!attributes.isVisible) {
                return [FTInvisibleElement constant];
            }
            FTSwiftUIRecordingBuilder *recordingBuilder = [self recordingBuilderWithRenderer:renderer wireframeID:wireframeID attributes:attributes context:context];
            if (!recordingBuilder) {
                return nil;
            }
            id<FTSRTextObfuscatingProtocol> textObfuscator = self.textObfuscator(context, attributes);
            FTUIHostingViewBuilder *builder = [[FTUIHostingViewBuilder alloc] init];
            builder.wireframeID = wireframeID;
            builder.attributes = attributes;
            builder.recordingBuilder = recordingBuilder;
            builder.textObfuscator = textObfuscator;
            FTSpecificElement *element = [[FTSpecificElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
            element.nodes = @[builder];
            return element;
        }
    }

    return nil;
}

- (FTSwiftUIRenderer *)rendererForHostingView:(UIView *)view API_AVAILABLE(ios(13.0)) {
    if (!self.reflectionBridge) {
        return nil;
    }
    FTSwiftUIReflectionBridge *bridge = self.reflectionBridge;
    return [bridge rendererForHostingView:view];
}

- (FTSwiftUIRecordingBuilder *)recordingBuilderWithRenderer:(FTSwiftUIRenderer *)renderer wireframeID:(int64_t)wireframeID attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context API_AVAILABLE(ios(13.0)) {
    if (!self.reflectionBridge || !renderer || !attributes) {
        return nil;
    }
    FTSwiftUIReflectionBridge *bridge = self.reflectionBridge;
    CGColorRef borderColor = attributes.layerBorderColor.cgColor;
    FTSwiftUIRecordingAttributes *recordingAttributes = [self recordingAttributesWithViewAttributes:attributes
                                                                                        borderColor:borderColor
                                                                                        textPrivacy:[attributes resolveTextAndInputPrivacyLevel:context.recorder]
                                                                                       imagePrivacy:[attributes resolveImagePrivacyLevel:context.recorder]
                                                                                        wireframeID:wireframeID];
    if (!recordingAttributes) {
        return nil;
    }
    return [bridge recordingBuilderForRenderer:renderer attributes:recordingAttributes];
}

- (FTSwiftUIRecordingAttributes *)recordingAttributesWithViewAttributes:(FTViewAttributes *)attributes
                                                             borderColor:(CGColorRef)borderColor
                                                             textPrivacy:(FTTextAndInputPrivacyLevel)textPrivacy
                                                            imagePrivacy:(FTImagePrivacyLevel)imagePrivacy
                                                             wireframeID:(int64_t)wireframeID API_AVAILABLE(ios(13.0)) {
    if (!self.reflectionBridge) {
        return nil;
    }

    FTSwiftUIReflectionBridge *bridge = self.reflectionBridge;
    FTSwiftUIRecordingAttributes *recordingAttributes = [bridge makeRecordingAttributes];
    recordingAttributes.frame = attributes.frame;
    recordingAttributes.clip = attributes.clip;
    recordingAttributes.alpha = attributes.alpha;
    recordingAttributes.backgroundColor = attributes.backgroundColor.cgColor;
    recordingAttributes.borderColor = borderColor;
    recordingAttributes.borderWidth = attributes.layerBorderWidth;
    recordingAttributes.cornerRadius = attributes.layerCornerRadius;
    recordingAttributes.textPrivacy = textPrivacy;
    recordingAttributes.imagePrivacy = imagePrivacy;
    recordingAttributes.wireframeID = wireframeID;
    return recordingAttributes;
}

+ (BOOL)isSwiftUIGraphicsView:(UIView *)view {
    Class graphicsViewClass = [FTUIHostingViewRecorder swiftUIGraphicsViewClass];
    return graphicsViewClass != Nil && [view.class isSubclassOfClass:graphicsViewClass];
}

+ (Class)swiftUIGraphicsViewClass {
    static Class graphicsViewClass = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        graphicsViewClass = NSClassFromString(@"SwiftUI._UIGraphicsView");
    });
    return graphicsViewClass;
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
-(NSString *)mimeType{
    return _mimeType;
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
    if (@available(iOS 13.0, *)) {
        FTSwiftUIRecordingResult *recordingResult = [self buildRecordingResultSafely];
        if (recordingResult) {
            NSArray<FTSRWireframe *> *wireframes = [self wireframesFromPayloads:recordingResult.wireframes
                                                                 textObfuscator:self.textObfuscator
                                                                        builder:builder];
            return wireframes;
        }
    }
    return [self fallbackWireframes];
}

- (nullable FTSwiftUIRecordingResult *)buildRecordingResultSafely API_AVAILABLE(ios(13.0)) {
    FTSwiftUIRecordingBuilder *recordingBuilder = self.recordingBuilder;
    if (!recordingBuilder) {
        return nil;
    }
    @try {
        return [recordingBuilder build];
    } @catch (NSException *exception) {
        FTInnerLogError(@"[Session Replay] SwiftUI recording build exception: %@", exception.description);
        return nil;
    }
}

- (NSArray<FTSRWireframe *> *)fallbackWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc] initWithIdentifier:self.wireframeID attributes:self.attributes];
    return wireframe ? @[wireframe] : @[];
}

- (NSArray<FTSRWireframe *> *)wireframesFromPayloads:(NSArray<id> *)payloads
                                      textObfuscator:(id<FTSRTextObfuscatingProtocol>)textObfuscator
                                             builder:(FTSessionReplayWireframesBuilder *)builder API_AVAILABLE(ios(13.0)) {
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray arrayWithCapacity:payloads.count];
    for (id payload in payloads) {
        FTSRWireframe *wireframe = nil;
        @try {
            wireframe = [self wireframeFromPayload:payload textObfuscator:textObfuscator builder:builder];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] SwiftUI wireframe payload exception: %@", exception.description);
        }
        if (wireframe) {
            [wireframes addObject:wireframe];
        }
    }
    return wireframes;
}

- (nullable id<FTSRResource>)resourceFromPayload:(id)payload API_AVAILABLE(ios(13.0)) {
    UIImage *image = [payload valueForKey:@"image"];
    if ([image isKindOfClass:UIImage.class]) {
        UIColor *tintColor = [payload valueForKey:@"tintColor"];
        if (![tintColor isKindOfClass:UIColor.class]) {
            tintColor = nil;
        }
        return [[FTUIImageResource alloc] initWithImage:image tintColor:tintColor traitCollection:nil];
    }

    NSString *identifier = [payload valueForKey:@"resourceIdentifier"];
    NSString *mimeType = [payload valueForKey:@"mimeType"] ?: @"image/png";
    NSData *data = [payload valueForKey:@"resourceData"];
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0 || ![data isKindOfClass:NSData.class]) {
        return nil;
    }
    return [[FTSwiftUIDataResource alloc] initWithIdentifier:identifier mimeType:mimeType data:data];
}

- (FTSRWireframe *)wireframeFromPayload:(id)payload
                         textObfuscator:(id<FTSRTextObfuscatingProtocol>)textObfuscator
                                builder:(FTSessionReplayWireframesBuilder *)builder API_AVAILABLE(ios(13.0)) {
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
            NSString *text = [payload valueForKey:@"text"] ?: @"";
            wireframe.text = [textObfuscator mask:text];
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
            id<FTSRResource> resource = [self resourceFromPayload:payload];
            if (resource) {
                FTSRImageWireframe *wireframe = [builder createImageWireframeWithID:identifier resource:resource frame:frame clip:clip];
                wireframe.mimeType = resource.mimeType ?: ([payload valueForKey:@"mimeType"] ?: @"image/png");
                return wireframe;
            }
            NSString *resourceIdentifier = [payload valueForKey:@"resourceIdentifier"];
            if (![resourceIdentifier isKindOfClass:NSString.class] || resourceIdentifier.length == 0) {
                FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc] initWithIdentifier:identifier frame:frame label:@"Unsupported image type"];
                wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
                return wireframe;
            }
            FTSRImageWireframe *wireframe = [[FTSRImageWireframe alloc] initWithIdentifier:identifier frame:frame];
            wireframe.resourceId = resourceIdentifier;
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

@end
