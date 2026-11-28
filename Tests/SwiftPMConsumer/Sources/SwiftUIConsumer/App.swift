import GuanceSDK
import GuanceSDKSwiftUI
import SwiftUI

@main
struct SwiftUIConsumer: App {
    init() {
        _ = FTSDKAgent.sharedInstance()
        FTRUMSwiftUI.trackTapAction(name: "launch")
    }

    var body: some Scene {
        WindowGroup {
            Text("Guance")
                .ftTrackRUMView(name: "Root")
        }
    }
}
