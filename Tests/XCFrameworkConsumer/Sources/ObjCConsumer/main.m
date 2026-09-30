@import GuanceSDK;

int main(void) {
    @autoreleasepool {
        FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"https://example.com"];
        FTSDKAgent *agent = [FTSDKAgent sharedInstance];
#if TARGET_OS_IOS || TARGET_OS_TV
        FTDefaultActionTrackingHandler *actionHandler = [FTDefaultActionTrackingHandler new];
        FTDefaultUIKitViewTrackingHandler *viewHandler = [FTDefaultUIKitViewTrackingHandler new];
        (void)actionHandler;
        (void)viewHandler;
#endif
        (void)config;
        (void)agent;
    }
    return 0;
}
