import GuanceSDK

@main
enum SwiftConsumer {
    static func main() {
        FTLog.enableCrashMonitorLog(true)
        _ = FTSDKAgent.sharedInstance()
        _ = FTDefaultActionTrackingHandler()
        _ = FTDefaultUIKitViewTrackingHandler()
    }
}
