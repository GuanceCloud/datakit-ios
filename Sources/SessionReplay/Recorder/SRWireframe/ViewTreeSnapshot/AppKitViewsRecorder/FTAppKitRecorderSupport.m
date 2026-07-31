//
//  FTAppKitRecorderSupport.m
//  SessionReplay AppKit views
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "FTAppKitRecorderSupport.h"
#import "FTSRUtils.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"

NSString *FTSRAppKitHexColor(NSColor *color, NSAppearance *appearance, NSString *fallback) {
    FTSRColorSnapshot *snapshot = [FTSRColorSnapshot snapshotWithColor:color
                                                       traitCollection:appearance];
    return snapshot.hexString ?: fallback;
}

@implementation FTNSTextBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc] initWithIdentifier:self.wireframeID
                                                                            frame:self.wireframeRect];
    wireframe.text = [self.textObfuscator mask:self.text] ?: @"";
    wireframe.border = [[FTSRShapeBorder alloc] initWithColor:self.attributes.layerBorderColor.hexString
                                                        width:self.attributes.layerBorderWidth];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]
        initWithBackgroundColor:self.backgroundColor ?: self.attributes.backgroundColor.hexString
                   cornerRadius:@(self.attributes.layerCornerRadius)
                         opacity:@(self.attributes.alpha)];
    wireframe.textStyle = [[FTSRTextStyle alloc]
        initWithSize:(int)round(self.fontSize)
               color:self.textColor
              family:self.fontFamily
      truncationMode:[FTSRUtils getTextStyleTruncationMode:self.lineBreakMode]];
    FTSRTextPosition *position = [FTSRTextPosition new];
    position.alignment = [[FTAlignment alloc] initWithTextAlignment:self.alignment
                                                           vertical:@"center"];
    position.padding = [[FTPadding alloc] initWithLeft:self.padding.left
                                                  top:self.padding.top
                                                right:self.padding.right
                                               bottom:self.padding.bottom];
    wireframe.textPosition = position;
    wireframe.clip = [[FTSRContentClip alloc] initWithFrame:self.wireframeRect
                                                       clip:self.attributes.clip];
    return @[wireframe];
}
@end

#endif
