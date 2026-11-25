import GuanceSDK

@main
enum SwiftConsumer {
    static func main() {
        FTLog.enableCrashMonitorLog(true)
        _ = FTSDKAgent.sharedInstance()
#if canImport(UIKit)
        _ = FTDefaultActionTrackingHandler()
        _ = FTDefaultUIKitViewTrackingHandler()
#endif
    }
}
