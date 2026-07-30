//
//  FTNSImageViewRecorder.m
//  SessionReplay AppKit views
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "FTAppKitViewRecorders.h"
#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreServices/CoreServices.h>
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

static CGRect FTSRAspectFitRect(CGRect frame, CGSize contentSize) {
    if (frame.size.width <= 0 || frame.size.height <= 0 ||
        contentSize.width <= 0 || contentSize.height <= 0) {
        return CGRectZero;
    }
    CGFloat scale = MIN(frame.size.width / contentSize.width,
                        frame.size.height / contentSize.height);
    CGSize size = CGSizeMake(contentSize.width * scale, contentSize.height * scale);
    return CGRectMake(CGRectGetMidX(frame) - size.width * 0.5,
                      CGRectGetMidY(frame) - size.height * 0.5,
                      size.width,
                      size.height);
}

static const size_t FTSRImageIdentifierMaximumDimension = 100;
static const size_t FTSRImageResourceMaximumDimension = 1000;
static void *FTSRNSImageResourceKey = &FTSRNSImageResourceKey;

static CGImageRef FTSRCreateScaledImage(CGImageRef image, size_t maximumDimension) {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    if (width == 0 || height == 0) {
        return nil;
    }
    CGFloat ratio = MAX(1.0, MAX((CGFloat)width / maximumDimension,
                                 (CGFloat)height / maximumDimension));
    size_t targetWidth = MAX((size_t)1, (size_t)llround((CGFloat)width / ratio));
    size_t targetHeight = MAX((size_t)1, (size_t)llround((CGFloat)height / ratio));
    if (targetWidth == width && targetHeight == height) {
        return CGImageRetain(image);
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(NULL,
                             targetWidth,
                             targetHeight,
                             8,
                             0,
                             colorSpace,
                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast |
                                 (CGBitmapInfo)kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return nil;
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context,
                       CGRectMake(0, 0, targetWidth, targetHeight),
                       image);
    CGImageRef scaledImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return scaledImage;
}

static NSString *FTSRImageIdentifier(CGImageRef image) {
    CGImageRef scaledImage =
        FTSRCreateScaledImage(image, FTSRImageIdentifierMaximumDimension);
    if (!scaledImage) {
        return nil;
    }
    size_t width = CGImageGetWidth(scaledImage);
    size_t height = CGImageGetHeight(scaledImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(NULL,
                             width,
                             height,
                             8,
                             width * 4,
                             colorSpace,
                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast |
                                 (CGBitmapInfo)kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        CGImageRelease(scaledImage);
        return nil;
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), scaledImage);
    CGImageRelease(scaledImage);

    void *bytes = CGBitmapContextGetData(context);
    size_t length = CGBitmapContextGetBytesPerRow(context) *
                    CGBitmapContextGetHeight(context);
    if (!bytes || length == 0) {
        CGContextRelease(context);
        return nil;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes, (CC_LONG)length, digest);
    CGContextRelease(context);
    NSMutableString *identifier =
        [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_MD5_DIGEST_LENGTH; index++) {
        [identifier appendFormat:@"%02x", digest[index]];
    }
    return identifier;
}

static NSData *FTSRPNGData(CGImageRef image) {
    CGImageRef scaledImage =
        FTSRCreateScaledImage(image, FTSRImageResourceMaximumDimension);
    if (!scaledImage) {
        return nil;
    }
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination =
        CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                         kUTTypePNG,
                                         1,
                                         NULL);
    if (!destination) {
        CGImageRelease(scaledImage);
        return nil;
    }
    CGImageDestinationAddImage(destination, scaledImage, NULL);
    BOOL finalized = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(scaledImage);
    return finalized ? [data copy] : nil;
}

static BOOL FTSRShouldRecordAppKitImage(NSImage *image, FTImagePrivacyLevel privacy) {
    switch (privacy) {
        case FTImagePrivacyLevelMaskNonBundledOnly:
            return image.name.length > 0 || image.isTemplate;
        case FTImagePrivacyLevelMaskAll:
            return NO;
        case FTImagePrivacyLevelMaskNone:
            return YES;
    }
}

@interface FTNSImageResource : NSObject <FTSRResource> {
    CGImageRef _image;
}
@property (nonatomic, copy) NSString *identifier;
- (instancetype)initWithCGImage:(CGImageRef)image;
@end

@implementation FTNSImageResource
@synthesize mimeType;

- (instancetype)initWithCGImage:(CGImageRef)image {
    self = [super init];
    if (self) {
        _image = CGImageRetain(image);
    }
    return self;
}
- (void)dealloc {
    if (_image) {
        CGImageRelease(_image);
    }
}
- (NSString *)mimeType {
    return @"image/png";
}
- (NSData *)calculateData {
    return FTSRPNGData(_image);
}
- (NSString *)calculateIdentifier {
    @synchronized (self) {
        if (!_identifier) {
            _identifier = FTSRImageIdentifier(_image) ?: NSUUID.UUID.UUIDString;
        }
        return _identifier;
    }
}
@end

static FTNSImageResource *FTSRResourceForImage(NSImage *image) {
    FTNSImageResource *resource =
        objc_getAssociatedObject(image, FTSRNSImageResourceKey);
    if (resource) {
        return resource;
    }
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cgImage) {
        return nil;
    }
    resource = [[FTNSImageResource alloc] initWithCGImage:cgImage];
    objc_setAssociatedObject(image,
                             FTSRNSImageResourceKey,
                             resource,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return resource;
}

@interface FTNSImageBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t backgroundID;
@property (nonatomic, assign) int64_t imageID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect contentFrame;
@property (nonatomic, strong, nullable) FTNSImageResource *resource;
@end

@implementation FTNSImageBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    FTSRShapeWireframe *background =
        [[FTSRShapeWireframe alloc] initWithIdentifier:self.backgroundID
                                            attributes:self.attributes];
    if (CGRectIsEmpty(self.contentFrame)) {
        return @[background];
    }
    FTSRWireframe *content = nil;
    if (self.resource) {
        content = [builder createImageWireframeWithID:self.imageID
                                             resource:self.resource
                                                frame:self.contentFrame
                                                 clip:self.attributes.clip];
    } else {
        FTSRPlaceholderWireframe *placeholder = [[FTSRPlaceholderWireframe alloc]
            initWithIdentifier:self.imageID
                         frame:self.contentFrame
                         label:@"Content Image"];
        placeholder.clip = [[FTSRContentClip alloc] initWithFrame:self.contentFrame
                                                             clip:self.attributes.clip];
        content = placeholder;
    }
    return @[background, content];
}
@end

@implementation FTNSImageViewRecorder
- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
    }
    return self;
}
- (FTSRNodeSemantics *)recorder:(NSView *)view
                      attributes:(FTViewAttributes *)attributes
                         context:(FTViewTreeRecordingContext *)context {
    if (![view isKindOfClass:NSImageView.class]) {
        return nil;
    }
    NSImageView *imageView = (NSImageView *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSArray<NSNumber *> *identifiers =
        [context.viewIDGenerator SRViewIDs:view size:2 nodeRecorder:self];
    FTNSImageBuilder *builder = [FTNSImageBuilder new];
    builder.backgroundID = identifiers[0].longLongValue;
    builder.imageID = identifiers[1].longLongValue;
    builder.attributes = attributes;
    NSImage *image = imageView.image;
    if (image) {
        switch (imageView.imageScaling) {
            case NSImageScaleAxesIndependently:
                builder.contentFrame = attributes.frame;
                break;
            case NSImageScaleNone:
                builder.contentFrame =
                    CGRectMake(CGRectGetMidX(attributes.frame) - image.size.width * 0.5,
                               CGRectGetMidY(attributes.frame) - image.size.height * 0.5,
                               image.size.width,
                               image.size.height);
                break;
            case NSImageScaleProportionallyDown:
            case NSImageScaleProportionallyUpOrDown:
                builder.contentFrame = FTSRAspectFitRect(attributes.frame, image.size);
                break;
        }
        FTImagePrivacyLevel privacy =
            [attributes resolveImagePrivacyLevel:context.recorder];
        if (FTSRShouldRecordAppKitImage(image, privacy)) {
            builder.resource = FTSRResourceForImage(image);
        }
    }
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
