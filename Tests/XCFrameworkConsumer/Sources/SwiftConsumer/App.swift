import GuanceSDK

@main
enum SwiftConsumer {
    static func main() {
        _ = FTSDKAgent.sharedInstance()
#if canImport(UIKit)
        _ = FTDefaultActionTrackingHandler()
        _ = FTDefaultUIKitViewTrackingHandler()
#endif
    }
}
