//
//  FTWKWebViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/18.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWKWebViewRecorder.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSystemColors.h"
#import <WebKit/WKWebView.h>
@implementation FTWKWebViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[WKWebView class]]){
        return nil;
    }
    WKWebView *webView = (WKWebView *)view;
    [context.webViewCache addObject:webView];
    FTWKWebViewBuilder *builder = [[FTWKWebViewBuilder alloc]init];
    builder.slotID = webView.hash;
    builder.attributes = attributes;
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

@implementation FTWKWebViewBuilder
-(CGRect)wireframeRect{
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    FTSRWebViewWireframe *wireframe = (FTSRWebViewWireframe *)[builder visibleWebViewWireframeWithID:self.slotID attributes:self.attributes];
    return @[wireframe];
}

@end
