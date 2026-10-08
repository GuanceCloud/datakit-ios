import Foundation

struct NativeHostEnvironment {
    private let values: [String: String]
    let projectRootURL: URL?

    init(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        sourceFilePath: String = #filePath,
        currentDirectoryURL: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ),
        bundleResourceURL: URL? = Bundle.main.resourceURL
    ) {
        let explicitRoot = processEnvironment["ORBITDESK_ELECTRON_PROJECT_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceURL = URL(fileURLWithPath: sourceFilePath)
        let candidates = [
            explicitRoot.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) },
            sourceURL.deletingLastPathComponent(),
            currentDirectoryURL,
            bundleResourceURL,
        ].compactMap { $0 }

        let projectRoot = candidates.lazy.compactMap(Self.findProjectRoot).first
        self.projectRootURL = projectRoot

        var fileValues: [String: String] = [:]
        if let projectRoot {
            for filename in [".env", ".env.local"] {
                let fileURL = projectRoot.appendingPathComponent(filename)
                guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }
                fileValues.merge(Self.parseEnvironment(contents)) { _, new in new }
            }
        }
        self.values = fileValues.merging(processEnvironment) { _, processValue in
            processValue
        }
    }

    func value(_ key: String) -> String {
        values[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var childProcessEnvironment: [String: String] {
        values
    }

    private static func findProjectRoot(startingAt startURL: URL) -> URL? {
        var directory = startURL.standardizedFileURL
        if !directory.hasDirectoryPath {
            directory.deleteLastPathComponent()
        }
        while directory.path != "/" {
            let packageJSON = directory.appendingPathComponent("package.json").path
            let electronMain = directory.appendingPathComponent("electron/main.cjs").path
            if FileManager.default.fileExists(atPath: packageJSON),
               FileManager.default.fileExists(atPath: electronMain) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }

    private static func parseEnvironment(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"") ||
                value.hasPrefix("'") && value.hasSuffix("'")) {
                value.removeFirst()
                value.removeLast()
            }
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }
}

enum ElectronLaunchConfigurationError: LocalizedError {
    case projectRootNotFound
    case electronNotInstalled(String)
    case rendererNotBuilt(String)

    var errorDescription: String? {
        switch self {
        case .projectRootNotFound:
            return "Could not find the Electron project; run from the example source or set ORBITDESK_ELECTRON_PROJECT_ROOT"
        case let .electronNotInstalled(path):
            return "Accessory Electron was not found at \(path); run npm install or npm run prepare:electron in this example"
        case let .rendererNotBuilt(path):
            return "The Renderer build was not found at \(path); run npm run build:renderer first"
        }
    }
}

struct ElectronLaunchConfiguration {
    let executableURL: URL
    let projectRootURL: URL

    static func resolve(
        environment: NativeHostEnvironment,
        fileManager: FileManager = .default
    ) throws -> ElectronLaunchConfiguration {
        guard let projectRoot = environment.projectRootURL else {
            throw ElectronLaunchConfigurationError.projectRootNotFound
        }

        let explicitExecutable = environment.value("ORBITDESK_ELECTRON_EXECUTABLE")
        let executableURL = explicitExecutable.isEmpty
            ? projectRoot.appendingPathComponent(
                "native-build/OrbitDeskElectronAccessory.app/Contents/MacOS/Electron"
            )
            : URL(fileURLWithPath: explicitExecutable)
        guard fileManager.isExecutableFile(atPath: executableURL.path) else {
            throw ElectronLaunchConfigurationError.electronNotInstalled(executableURL.path)
        }

        if environment.value("VITE_DEV_SERVER_URL").isEmpty {
            let rendererURL = projectRoot.appendingPathComponent("dist/index.html")
            guard fileManager.fileExists(atPath: rendererURL.path) else {
                throw ElectronLaunchConfigurationError.rendererNotBuilt(rendererURL.path)
            }
        }
        return ElectronLaunchConfiguration(
            executableURL: executableURL,
            projectRootURL: projectRoot
        )
    }
}
