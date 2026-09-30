import GuanceSDK

@main
enum SwiftConsumer {
    static func main() {
        _ = FTSDKAgent.sharedInstance()
        _ = FTDefaultActionTrackingHandler()
        _ = FTDefaultUIKitViewTrackingHandler()
    }
}
