import AppKit
import Darwin
import Foundation
import GuanceElectronWebView
import GuanceSDK
import GuanceSessionReplay

private enum NativeHostError: LocalizedError {
    case missingNativeConfiguration

    var errorDescription: String? {
        switch self {
        case .missingNativeConfiguration:
            return "Configure a Native RUM App ID and a DataKit or DataWay endpoint"
        }
    }
}

private let nativeHostEnvironment = NativeHostEnvironment()

private func environment(_ key: String) -> String {
    nativeHostEnvironment.value(key)
}

private func boolean(_ key: String, fallback: Bool) -> Bool {
    let value = environment(key).lowercased()
    guard !value.isEmpty else { return fallback }
    return !["0", "false", "no", "off"].contains(value)
}

private func percentage(_ key: String, fallback: Int) -> Int {
    guard let value = Int(environment(key)) else { return fallback }
    return min(100, max(0, value))
}

private final class NativeHostAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusLabel: NSTextField?
    private var processesLabel: NSTextField?
    private var launchElectronButton: NSButton?
    private var launchAnotherElectronButton: NSButton?
    private let electronProcesses = ElectronProcessController(pidFileURL: {
        let path = environment("ORBITDESK_ELECTRON_PID_FILE")
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }())
    private var rumActive = false
    private var bridgeReady = false
    private(set) var exitStatus: Int32 = 0

    private var isSmokeTest: Bool {
        boolean("GUANCE_EXAMPLE_SMOKE", fallback: false)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        electronProcesses.onExit = { [weak self] child in
            guard let self else { return }
            self.updateProcessControls()
            self.statusLabel?.stringValue = "Electron #\(child.instanceID) exited · \(self.electronProcesses.children.count) running"
            print("[native-host] Electron #\(child.instanceID) PID \(child.process.processIdentifier) exited: \(child.process.terminationStatus)")
            if self.isSmokeTest {
                if child.process.terminationStatus != 0 { self.exitStatus = 1 }
                if self.electronProcesses.children.isEmpty { NSApp.terminate(nil) }
            }
        }
        do {
            try startNativeSDKAndBridge()
            createWindow(status: "Native SDK active · Click Open Electron to launch the UI process")
            if isSmokeTest {
                try launchElectron()
                if boolean("GUANCE_EXAMPLE_SMOKE_MULTI", fallback: false) {
                    try launchElectron()
                }
            }
        } catch {
            createWindow(status: "Startup failed: \(error.localizedDescription)")
            if isSmokeTest {
                exitStatus = 1
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
    }

    private func startNativeSDKAndBridge() throws {
        let appID = environment("GUANCE_NATIVE_APP_ID")
        let datakitURL = environment("GUANCE_NATIVE_DATAKIT_URL")
        let datawayURL = environment("GUANCE_NATIVE_DATAWAY_URL")
        let clientToken = environment("GUANCE_NATIVE_CLIENT_TOKEN")
        guard !appID.isEmpty,
              !datakitURL.isEmpty || (!datawayURL.isEmpty && !clientToken.isEmpty)
        else {
            throw NativeHostError.missingNativeConfiguration
        }

        let sdkConfig: FTSDKConfig
        if !datakitURL.isEmpty {
            sdkConfig = FTSDKConfig(datakitUrl: datakitURL)
        } else {
            sdkConfig = FTSDKConfig(
                datawayUrl: datawayURL,
                clientToken: clientToken
            )
        }
        sdkConfig.enableSDKDebugLog = boolean("GUANCE_NATIVE_DEBUG", fallback: true)
        sdkConfig.env = environment("GUANCE_NATIVE_ENV").isEmpty
            ? "development" : environment("GUANCE_NATIVE_ENV")
        sdkConfig.service = environment("GUANCE_NATIVE_SERVICE").isEmpty
            ? "orbitdesk-external-native" : environment("GUANCE_NATIVE_SERVICE")
        sdkConfig.autoSync = true
        FTSDKAgent.start(withConfigOptions: sdkConfig)

        let rumConfig = FTRumConfig(appid: appID)
        rumConfig.enableTraceWebView = true
        rumConfig.enableTraceUserView = true
        rumConfig.enableTraceUserAction = boolean(
            "GUANCE_NATIVE_ACTION_TRACKING",
            fallback: true
        )
        rumConfig.enableTraceUserResource = true
        rumConfig.enableTrackAppCrash = true
        rumConfig.enableTrackAppFreeze = true
        rumConfig.enableTrackAppANR = true
        rumConfig.globalContext = [
            "hybrid_architecture": "native-owner-electron-child-process",
            "bridge_mode": "external",
        ]
        FTSDKAgent.sharedInstance().startRum(withConfigOptions: rumConfig)
        rumActive = true

        if boolean("GUANCE_NATIVE_LOGGING", fallback: true) {
            let loggerConfig = FTLoggerConfig()
            loggerConfig.sampleRate = Int32(percentage(
                "GUANCE_NATIVE_LOGGING_SAMPLE_RATE",
                fallback: 100
            ))
            loggerConfig.enableCustomLog = true
            loggerConfig.enableWebViewLog = true
            loggerConfig.enableLinkRumData = true
            loggerConfig.globalContext = [
                "hybrid_architecture": "native-owner-electron-child-process",
                "bridge_mode": "external",
            ]
            FTSDKAgent.sharedInstance().startLogger(withConfigOptions: loggerConfig)
        }

        bridgeReady = true

        if boolean("GUANCE_NATIVE_SESSION_REPLAY", fallback: true) {
            let replayConfig = FTSessionReplayConfig()
            replayConfig.sampleRate = Int32(percentage(
                "GUANCE_NATIVE_SESSION_REPLAY_SAMPLE_RATE",
                fallback: 100
            ))
            replayConfig.sessionReplayOnErrorSampleRate = Int32(percentage(
                "GUANCE_NATIVE_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE",
                fallback: 100
            ))
            replayConfig.textAndInputPrivacy = .maskSensitiveInputs
            replayConfig.touchPrivacy = .show
            replayConfig.imagePrivacy = .maskNonBundledOnly
            FTRumSessionReplay.shared().start(with: replayConfig)
        }
    }

    private func launchElectron() throws {
        let launchConfiguration = try ElectronLaunchConfiguration.resolve(
            environment: nativeHostEnvironment
        )

        let task = Process()
        task.executableURL = launchConfiguration.executableURL
        task.currentDirectoryURL = launchConfiguration.projectRootURL
        task.arguments = [launchConfiguration.projectRootURL.path]
        // Include this example's .env.local settings (e.g. the Vite URL).
        // The controller retains a separate server and injects its credentials.
        task.environment = nativeHostEnvironment.childProcessEnvironment
        let child = try electronProcesses.launch(task)
        updateProcessControls()
        statusLabel?.stringValue = "Electron #\(child.instanceID) launched · independent Bridge Server"
        print("[native-host] Launched Electron #\(child.instanceID) PID \(task.processIdentifier)")
    }

    private func updateProcessControls() {
        let children = electronProcesses.children.values.sorted { $0.instanceID < $1.instanceID }
        launchElectronButton?.isEnabled = bridgeReady && children.isEmpty
        launchAnotherElectronButton?.isEnabled = bridgeReady && children.count == 1
        processesLabel?.stringValue = children.isEmpty
            ? "No Electron child processes running"
            : children.map { "Electron #\($0.instanceID) · PID \($0.process.processIdentifier) · independent bridge" }
                .joined(separator: "\n")
    }

    private func createWindow(status: String) {
        guard window == nil else {
            statusLabel?.stringValue = status
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OrbitDesk · Native External Mode Host"
        window.center()

        let title = NSTextField(labelWithString: "macOS Native Host")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        let detail = NSTextField(wrappingLabelWithString:
            "One Native SDK, up to two Electron Main processes. Each child has its own Bridge Server."
        )
        detail.textColor = .secondaryLabelColor
        let statusLabel = NSTextField(labelWithString: status)
        statusLabel.textColor = .systemBlue
        self.statusLabel = statusLabel

        let processesLabel = NSTextField(labelWithString: "No Electron child processes running")
        processesLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        self.processesLabel = processesLabel

        let openElectron = NSButton(
            title: "Open Electron",
            target: self,
            action: #selector(openElectron)
        )
        openElectron.isEnabled = bridgeReady
        self.launchElectronButton = openElectron
        let openAnotherElectron = NSButton(
            title: "Open Another Electron",
            target: self,
            action: #selector(openAnotherElectron)
        )
        openAnotherElectron.isEnabled = false
        self.launchAnotherElectronButton = openAnotherElectron
        let processButtons = NSStackView(views: [openElectron, openAnotherElectron])
        processButtons.orientation = .horizontal
        processButtons.spacing = 12
        let action = NSButton(
            title: "Record Native Action",
            target: self,
            action: #selector(recordAction)
        )
        let request = NSButton(
            title: "Send Native Request",
            target: self,
            action: #selector(runRequest)
        )
        let flush = NSButton(
            title: "Flush Now",
            target: self,
            action: #selector(flushData)
        )
        let buttons = NSStackView(views: [action, request, flush])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [title, detail, statusLabel, processesLabel, processButtons, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 48),
                stack.trailingAnchor.constraint(
                    lessThanOrEqualTo: content.trailingAnchor,
                    constant: -48
                ),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openElectron() {
        guard bridgeReady, electronProcesses.children.isEmpty else { return }
        openAnotherElectron()
    }

    @objc private func openAnotherElectron() {
        guard bridgeReady, electronProcesses.children.count < 2 else { return }
        do {
            try launchElectron()
        } catch {
            updateProcessControls()
            statusLabel?.stringValue = "Electron launch failed: \(error.localizedDescription)"
        }
    }

    @objc private func recordAction() {
        guard rumActive else { return }
        FTExternalDataManager.shared().addAction(
            "External Host Native Action",
            actionType: "click",
            property: ["process_owner": "native"]
        )
        statusLabel?.stringValue = "Recorded one Native Action"
    }

    @objc private func runRequest() {
        guard rumActive else { return }
        let configured = environment("ORBITDESK_NATIVE_REQUEST_URL")
        guard let url = URL(string: configured.isEmpty
            ? "https://dummyjson.com/test" : configured) else { return }
        statusLabel?.stringValue = "Sending Native URLSession request..."
        URLSession.shared.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async {
                self?.statusLabel?.stringValue = error.map {
                    "Native request failed: \($0.localizedDescription)"
                } ?? "Native URLSession request completed"
            }
        }.resume()
    }

    @objc private func flushData() {
        guard rumActive else { return }
        FTSDKAgent.sharedInstance().flushSyncData()
        statusLabel?.stringValue = "Requested a Native SDK flush"
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridgeReady = false
        electronProcesses.terminateAll()
    }
}

private let application = NSApplication.shared
private let delegate = NativeHostAppDelegate()
private let terminationSource = DispatchSource.makeSignalSource(
    signal: SIGTERM,
    queue: .main
)
private let interruptSource = DispatchSource.makeSignalSource(
    signal: SIGINT,
    queue: .main
)
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
terminationSource.setEventHandler {
    application.terminate(nil)
}
interruptSource.setEventHandler {
    application.terminate(nil)
}
terminationSource.resume()
interruptSource.resume()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
Darwin.exit(delegate.exitStatus)
