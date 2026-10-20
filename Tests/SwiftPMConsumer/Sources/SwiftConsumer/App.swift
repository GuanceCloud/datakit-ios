import GuanceSDK
import Foundation

final class ConsumerINVRule: NSObject, FTRUMNextViewActionPredicate {
    func isLastAction(_ params: FTRUMNextViewActionParams) -> Bool {
        params.actionType == "custom" && params.timeToNextViewNs <= 5_000_000_000
    }
}
final class ConsumerTNSRule: NSObject, FTRUMNetworkSettledResourcePredicate {
    func isInitialResource(_ params: FTRUMNetworkSettledResourceParams) -> Bool {
        params.resourceURL?.contains("/api/") == true && params.timeSinceViewStartNs >= 0
    }
}

@main
enum SwiftConsumer {
    static func main() {
        _ = FTSDKAgent.sharedInstance()
        let rum = FTRumConfig(appid: "app")
        rum.nextViewActionPredicate = FTRUMTimeBasedNextViewActionPredicate(maxTimeNs: 5_000_000_000)
        rum.networkSettledResourcePredicate = FTRUMTimeBasedNetworkSettledPredicate(thresholdNs: 200_000_000)
        rum.nextViewActionPredicate = ConsumerINVRule()
        rum.networkSettledResourcePredicate = ConsumerTNSRule()
        rum.nextViewActionPredicate = nil
        rum.networkSettledResourcePredicate = nil
#if canImport(UIKit)
        _ = FTDefaultActionTrackingHandler()
        _ = FTDefaultUIKitViewTrackingHandler()
#endif
    }
}
