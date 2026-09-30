@import GuanceSessionReplay;

@interface IntegrationBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int64_t wireframeID;
@end

@implementation IntegrationBuilder

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc] initWithIdentifier:self.wireframeID
                                                                          frame:self.attributes.frame];
    wireframe.text = [[FTSRTextObfuscatingFactory staticTextObfuscator:FTTextAndInputPrivacyLevelMaskSensitiveInputs]
                      mask:@"example"];
    return @[wireframe];
}

@end

@interface IntegrationRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@implementation IntegrationRecorder

- (FTSRNodeSemantics *)recorder:(FTSRPlatformView *)view
                    attributes:(FTViewAttributes *)attributes
                       context:(FTViewTreeRecordingContext *)context {
    IntegrationBuilder *builder = [IntegrationBuilder new];
    builder.attributes = attributes;
    builder.wireframeRect = attributes.frame;
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    FTSpecificElement *element = [[FTSpecificElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    (void)[FTSystemColors labelColorStr];
    return element;
}

@end

int main(void) {
    @autoreleasepool {
        FTSessionReplayConfig *config = [FTSessionReplayConfig new];
        config.additionalNodeRecorders = @[[IntegrationRecorder new]];
        config.externalRecorderMode = NO;

        FTRumSessionReplay *replay = [FTRumSessionReplay sharedInstance];
        NSDictionary *context = [replay currentExternalRUMContext];
        (void)context[FTSessionReplayRUMContextViewIDKey];
        [replay writeExternalSegment:@"{}" viewID:@"view"];
        [replay saveExternalImageResourceData:[NSData data] mimeType:@"image/png"];
        [replay setExternalHasReplay:YES];
        [replay updateExternalRecordCount:1 viewID:@"view"];

        id<FTSRNodeWireframesBuilder> builder = nil;
        (void)builder;
        (void)config;
    }
    return 0;
}
