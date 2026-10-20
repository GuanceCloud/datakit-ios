#if os(macOS)
import XCTest
import GuanceSessionReplay

final class ReplayLifecycleTests: XCTestCase {
    struct Runtime {
        let replay: FTRumSessionReplay
        let feature: NSObject
        let coordinator: NSObject
        let storage: NSObject
        let processors: DispatchQueue
        let writes: DispatchQueue
        let directory: URL

        func files(_ state: String, resources: Bool = false) throws -> [URL] {
            let name = resources ? "session-replay-resources" : "session-replay"
            let suffix = state == "granted" ? "" : ".\(state)"
            return try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent(name + suffix), includingPropertiesForKeys: nil)
        }
    }

    func runtime() throws -> Runtime {
        let replay = FTRumSessionReplay()
        let core = try XCTUnwrap(replay.value(forKey: "coreDirectory") as? NSObject)
        let parent = try XCTUnwrap(core.value(forKey: "directory") as? NSObject)
        let directory = try XCTUnwrap(parent.perform(NSSelectorFromString("createSubdirectoryWithPath:"), with: "test-\(UUID().uuidString)")?.takeUnretainedValue() as? NSObject)
        core.setValue(directory, forKey: "directory")
        let url = try XCTUnwrap(directory.value(forKey: "url") as? URL)
        let config = FTSessionReplayConfig()
        config.externalRecorderMode = true
        replay.start(with: config)
        let features = try XCTUnwrap(replay.value(forKey: "features") as? [String: NSObject])
        let feature = try XCTUnwrap(features["session-replay"])
        let coordinator = try XCTUnwrap(feature.value(forKey: "recordingCoordinator") as? NSObject)
        coordinator.setValue(0, forKey: "sampleState")
        coordinator.setValue(["app_id": "app", "session_id": "session", "view_id": "view"], forKey: "currentRUMContext")
        let scope = try XCTUnwrap(feature.value(forKey: "recordScope") as? NSObject)
        let storage = try XCTUnwrap(scope.value(forKey: "storage") as? NSObject)
        let processors = try XCTUnwrap(feature.value(forKey: "processorsQueue") as? DispatchQueue)
        let writes = try XCTUnwrap(replay.value(forKey: "readWriteQueue") as? DispatchQueue)
        addTeardownBlock {
            replay.shutdown()
            processors.sync {}
            processors.sync {}
            writes.sync {}
            try FileManager.default.removeItem(at: url)
        }
        return Runtime(replay: replay, feature: feature, coordinator: coordinator, storage: storage, processors: processors, writes: writes, directory: url)
    }

    func drain(_ runtime: Runtime) {
        runtime.processors.sync {}
        runtime.processors.sync {}
        runtime.writes.sync {}
    }

    func testShutdownInvalidatesQueuedWorkAndOldContextAfterReinitialization() throws {
        let runtime = try runtime()
        runtime.processors.suspend()
        runtime.replay.writeExternalSegment("old-runtime", viewID: "view")
        runtime.replay.shutdown()
        runtime.replay.start(with: FTSessionReplayConfig())
        let features = try XCTUnwrap(runtime.replay.value(forKey: "features") as? [String: NSObject])
        XCTAssertFalse(features["session-replay"] === runtime.feature)
        runtime.processors.resume()
        drain(runtime)
        XCTAssertEqual(try runtime.files("granted").count, 0)
        XCTAssertEqual(runtime.coordinator.value(forKey: "recordingEnabled") as? Bool, false)
        XCTAssertEqual(runtime.storage.value(forKey: "invalidated") as? Bool, true)
    }

    func testShutdownAllowsWritesAlreadyQueuedForPersistence() throws {
        let runtime = try runtime()
        runtime.writes.sync {}
        runtime.writes.suspend()
        runtime.replay.writeExternalSegment("queued-write", viewID: "view")
        runtime.processors.sync {}
        runtime.replay.shutdown()
        runtime.writes.resume()
        drain(runtime)
        XCTAssertEqual(try storedPayloads(runtime), [Data("queued-write".utf8)])
    }

    func sendWebRecord(_ runtime: Runtime, type: Int, timestamp: Int) {
        runtime.feature.perform(NSSelectorFromString("handleWebViewSRMessage:"), with: [
            "slotId": "slot", "view": ["id": "view"],
            "data": ["type": type, "timestamp": timestamp]
        ])
    }

    func storedPayloads(_ runtime: Runtime, state: String = "granted", resources: Bool = false) throws -> [Data] {
        var payloads: [Data] = []
        for file in try runtime.files(state, resources: resources).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let data = try Data(contentsOf: file)
            var offset = 0
            while offset < data.count {
                guard offset + 6 <= data.count else {
                    XCTFail("Incomplete TLV header")
                    return payloads
                }
                let type = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
                let length = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset + 2, as: UInt32.self) })
                XCTAssertEqual(type, 1)
                offset += 6
                guard length <= data.count - offset else {
                    XCTFail("Incomplete TLV payload")
                    return payloads
                }
                payloads.append(data.subdata(in: offset..<(offset + length)))
                offset += length
            }
        }
        return payloads
    }

    func webRecords(_ runtime: Runtime, state: String = "granted") throws -> [NSDictionary] {
        XCTAssertTrue(try runtime.files(state).allSatisfy { $0.lastPathComponent.hasPrefix("w_") })
        return try storedPayloads(runtime, state: state).flatMap { data in
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            return try XCTUnwrap(payload["records"] as? [NSDictionary])
        }
    }

    func testShutdownClosesSelectionButAllowsSubmittedWebWritesAcrossReinitialization() throws {
        for delayPersistence in [false, true] {
            let runtime = try runtime()
            runtime.writes.sync {}
            let delayedQueue = delayPersistence ? runtime.writes : runtime.processors
            delayedQueue.suspend()
            sendWebRecord(runtime, type: 2, timestamp: 1000)
            if delayPersistence { runtime.processors.sync {} }
            runtime.replay.shutdown()
            runtime.replay.shutdown()
            let config = FTSessionReplayConfig()
            config.externalRecorderMode = true
            runtime.replay.start(with: config)
            let features = try XCTUnwrap(runtime.replay.value(forKey: "features") as? [String: NSObject])
            XCTAssertFalse(features["session-replay"] === runtime.feature)
            sendWebRecord(runtime, type: 3, timestamp: 1100)
            delayedQueue.resume()
            drain(runtime)
            let expected: [NSDictionary] = delayPersistence ? [["type": 2, "timestamp": 1000, "slotId": "slot"] as NSDictionary] : []
            XCTAssertEqual(try webRecords(runtime), expected)
        }
    }

    func testRetainedScopeSelectsNOPOnContextQueueAfterShutdown() throws {
        let runtime = try runtime()
        let scope = try XCTUnwrap(runtime.feature.value(forKey: "recordScope") as? NSObject)
        let contextQueue = try XCTUnwrap(runtime.replay.value(forKey: "contextQueue") as? DispatchQueue)
        let grantedState: @convention(block) () -> Int = { 0 }
        scope.setValue(grantedState, forKey: "trackingConsentProvider")
        let queueKey = DispatchSpecificKey<Bool>()
        contextQueue.setSpecific(key: queueKey, value: true)
        runtime.replay.shutdown()
        var callbacks = 0
        let write: @convention(block) (NSObject, NSObject) -> Void = { context, writer in
            XCTAssertEqual(DispatchQueue.getSpecific(key: queueKey), true)
            XCTAssertEqual(context.value(forKey: "trackingConsent") as? Int, 1)
            XCTAssertEqual(NSStringFromClass(type(of: writer)), "FTNoOpWriter")
            writer.perform(NSSelectorFromString("write:"), with: Data("rejected".utf8))
            callbacks += 1
        }
        for selector in ["eventWriteContext:", "normalResourceWriteContext:", "webViewEventWriteContext:"] {
            scope.perform(NSSelectorFromString(selector), with: write)
        }
        drain(runtime)
        XCTAssertEqual(callbacks, 3)
        XCTAssertEqual(try runtime.files("granted").count, 0)
    }

    func testQueuedMetadataWriteReadAndDeleteFinishAfterShutdown() throws {
        let runtime = try runtime()
        let resourceWriter = try XCTUnwrap(runtime.feature.value(forKey: "externalResourceWriter") as? NSObject)
        let dataStore = try XCTUnwrap(resourceWriter.value(forKey: "dataStore") as? NSObject)
        drain(runtime)
        runtime.writes.suspend()
        runtime.replay.saveExternalImageResourceData(Data("image".utf8), mimeType: "image/png")
        runtime.processors.sync {}
        var callbacks = 0
        let read: @convention(block) (NSError?, NSData?, UInt16) -> Void = { error, data, version in
            XCTAssertNil(error)
            XCTAssertEqual(version, 0)
            let identifiers = data.flatMap { try? JSONSerialization.jsonObject(with: $0 as Data) as? [String] }
            XCTAssertEqual(identifiers, ["78805a221a988e79ef3f42d7c5bfd418"])
            callbacks += 1
        }
        let readDeleted: @convention(block) (NSError?, NSData?, UInt16) -> Void = { error, data, version in
            XCTAssertNil(error)
            XCTAssertNil(data)
            XCTAssertEqual(version, UInt16.max)
            callbacks += 1
        }
        dataStore.perform(NSSelectorFromString("valueForKey:callback:"), with: "ft-known-resources", with: read)
        dataStore.perform(NSSelectorFromString("removeValueForKey:"), with: "ft-known-resources")
        dataStore.perform(NSSelectorFromString("valueForKey:callback:"), with: "ft-known-resources", with: readDeleted)
        runtime.replay.shutdown()
        runtime.writes.resume()
        withExtendedLifetime(dataStore) { drain(runtime) }
        XCTAssertEqual(callbacks, 2)
        XCTAssertEqual(try runtime.files("granted", resources: true).count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtime.directory.appendingPathComponent("0/session-replay-resources/ft-known-resources").path))
    }

    func testRetainedReaderCanFinishFileAcknowledgementAfterShutdown() throws {
        let runtime = try runtime()
        runtime.replay.writeExternalSegment("uploaded", viewID: "view")
        drain(runtime)
        let reader = try XCTUnwrap(runtime.storage.perform(NSSelectorFromString("reader"))?.takeUnretainedValue() as? NSObject)
        let directory = try XCTUnwrap(runtime.storage.value(forKeyPath: "directories.granted") as? NSObject)
        let files = try XCTUnwrap(directory.value(forKey: "files") as? [NSObject])
        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        let batch = try XCTUnwrap(reader.perform(NSSelectorFromString("readBatch:"), with: file)?.takeUnretainedValue() as? NSObject)
        runtime.replay.shutdown()
        reader.perform(NSSelectorFromString("markBatchAsRead:"), with: batch)
        XCTAssertEqual(try runtime.files("granted").count, 0)
    }

}

#endif
