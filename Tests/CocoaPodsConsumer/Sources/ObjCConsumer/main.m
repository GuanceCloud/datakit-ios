@import GuanceSDK;
#import <GuanceSDK/FTMessageReceiver.h>
#import <GuanceSDK/FTModuleManager.h>
#import <GuanceSDK/FTSessionReplayConfig+FrameworkIntegration.h>
#import <GuanceSDK/FTSRNodeSemantics.h>
#import <GuanceSDK/FTSRWireframe.h>

int main(void) {
    @autoreleasepool {
        FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"https://example.com"];
        FTSDKAgent *agent = [FTSDKAgent sharedInstance];
        FTDefaultActionTrackingHandler *actionHandler = [FTDefaultActionTrackingHandler new];
        FTDefaultUIKitViewTrackingHandler *viewHandler = [FTDefaultUIKitViewTrackingHandler new];
        FTSessionReplayConfig *replayConfig = [FTSessionReplayConfig new];
        replayConfig.additionalNodeRecorders = @[];
        FTSRNodeSemantics *semantics = [[FTSRNodeSemantics alloc] initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
        NSDictionary *rumContext = [[FTRumSessionReplay sharedInstance] currentExternalRUMContext];
        id<FTMessageReceiver> receiver = nil;
        (void)[FTModuleManager sharedInstance];
        (void)FTMessageKeySessionHasReplay;
        (void)config;
        (void)agent;
        (void)actionHandler;
        (void)viewHandler;
        (void)replayConfig;
        (void)semantics;
        (void)rumContext;
        (void)receiver;
    }
    return 0;
}
