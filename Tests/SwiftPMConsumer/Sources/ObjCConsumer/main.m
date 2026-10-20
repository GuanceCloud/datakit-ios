@import GuanceSDK;

int main(void) {
    @autoreleasepool {
        FTSDKConfig *config = [[FTSDKConfig alloc] initWithDatakitUrl:@"https://example.com"];
        FTRumConfig *rum = [[FTRumConfig alloc] initWithAppid:@"app"];
        rum.nextViewActionPredicate = [[FTRUMTimeBasedNextViewActionPredicate alloc] initWithMaxTimeNs:5000000000LL];
        rum.networkSettledResourcePredicate = [[FTRUMTimeBasedNetworkSettledPredicate alloc] initWithThresholdNs:200000000];
        rum.nextViewActionPredicate = nil;
        rum.networkSettledResourcePredicate = nil;
        FTSDKAgent *agent = [FTSDKAgent sharedInstance];
        FTRemoteConfigModel *remoteConfig = [FTRemoteConfigModel new];
        (void)[remoteConfig toDictionary];
        [[FTURLSessionInterceptor shared] removeTraceHandlerWithKey:@"cancelled-resource"];
        id<FTMessageReceiver> receiver = nil;
        (void)[FTModuleManager sharedInstance];
        (void)FTMessageKeySessionHasReplay;
        (void)receiver;
#if TARGET_OS_IOS || TARGET_OS_TV
        FTDefaultActionTrackingHandler *actionHandler = [FTDefaultActionTrackingHandler new];
        FTDefaultUIKitViewTrackingHandler *viewHandler = [FTDefaultUIKitViewTrackingHandler new];
        (void)actionHandler;
        (void)viewHandler;
#endif
        // Verify that framework adapters can use these APIs via the SPM product.
        FTExternalDataManager *adapter = [FTExternalDataManager sharedManager];
        [adapter onCreateView:@"framework-view" loadTime:@1000000 loadStartEpochNs:@1700000000000000123LL];
        [adapter startViewWithName:@"framework-view" property:nil trackingType:FTRUMViewTrackingTypeAutomatic];
        (void)config;
        (void)agent;
    }
    return 0;
}
