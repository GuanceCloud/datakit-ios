//
//  RUMAutomaticViewLifecycleTests.swift
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest
import GuanceSDK

private final class LifecycleWriter: NSObject, FTRUMDataWriteProtocol {
    struct Event {
        let source: String
        let tags: [AnyHashable: Any]
        let fields: [AnyHashable: Any]
        let time: Int64
        let updateTime: Int64
    }

    var events: [Event] = []

    func rumWrite(_ source: String, tags: [AnyHashable: Any], fields: [AnyHashable: Any],
                  dynamicContext: [AnyHashable: Any], time: Int64) {
        rumWrite(source, tags: tags, fields: fields, dynamicContext: dynamicContext,
                 time: time, updateTime: time)
    }

    func rumWrite(_ source: String, tags: [AnyHashable: Any], fields: [AnyHashable: Any],
                  dynamicContext: [AnyHashable: Any], time: Int64, updateTime: Int64) {
        events.append(Event(source: source, tags: tags, fields: fields,
                            time: time, updateTime: updateTime))
    }

    func rumWrite(_ source: String, tags: [AnyHashable: Any], fields: [AnyHashable: Any],
                  dynamicContext: [AnyHashable: Any], time: Int64, updateTime: Int64,
                  cache: Bool) {
        rumWrite(source, tags: tags, fields: fields, dynamicContext: dynamicContext,
                 time: time, updateTime: updateTime)
    }

    func rumWriteAssembledData(_ source: String, tags: [AnyHashable: Any],
                              fields: [AnyHashable: Any], time: Int64) {
        rumWrite(source, tags: tags, fields: fields, dynamicContext: [:], time: time)
    }
}

final class RUMAutomaticViewLifecycleTests: XCTestCase {
    private func fixture(trackingType: FTRUMViewTrackingType? = nil) throws -> (FTRUMManager, FTRUMDependencies, LifecycleWriter, NSObject, DispatchQueue) {
        let dependencies = FTRUMDependencies()
        dependencies.sampleRate = 100
        dependencies.appId = "lifecycle-tests"
        let writer = LifecycleWriter()
        dependencies.writer = writer
        let manager = FTRUMManager(rumDependencies: dependencies)
        manager.syncProcess()
        dependencies.appStateHistory?.stopMonitoring()
        dependencies.appStateHistory = FTRUMAppStateHistory(state: "foreground", timeNs: 99_000_000_000)
        manager.appState = .run
        if let trackingType {
            manager.startView(withName: "automatic", property: nil, trackingType: trackingType)
        } else {
            manager.startView(withViewID: "auto-view", viewName: "automatic", property: nil)
        }
        manager.syncProcess()
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let views = try XCTUnwrap(session.value(forKey: "viewHandlers") as? [NSObject])
        let view = try XCTUnwrap(views.last)
        view.setValue(Date(timeIntervalSince1970: 100), forKey: "viewStartTime")
        view.setValue(NSNumber(value: Int64(100) * 1_000_000_000), forKey: "loadingStartEpochNs")
        session.setValue(Date(timeIntervalSince1970: 100), forKey: "sessionStartTime")
        session.setValue(Date(timeIntervalSince1970: 100), forKey: "lastInteractionTime")
        let queue = try XCTUnwrap(manager.value(forKey: "rumQueue") as? DispatchQueue)
        writer.events.removeAll()
        return (manager, dependencies, writer, view, queue)
    }

    private func background(_ manager: FTRUMManager, dependencies: FTRUMDependencies,
                            at seconds: TimeInterval) throws {
        let history = try XCTUnwrap(dependencies.appStateHistory)
        XCTAssertTrue(history.recordState("background", timeNs: Int64(seconds * 1_000_000_000)))
        let delegate = try XCTUnwrap(manager as? FTRUMAppStateHistoryDelegate)
        delegate.appStateHistory(history, didChange: .backgroundOnly,
                                 time: Date(timeIntervalSince1970: seconds))
    }

    private func process(_ model: FTRUMDataModel, manager: FTRUMManager,
                         queue: DispatchQueue) throws {
        let processor = try XCTUnwrap(manager as? FTRUMSessionProtocol)
        queue.sync {
            XCTAssertTrue(processor.process(model, context: FTRUMPropertySnapshot(tags: [:], customKeys: [])))
        }
    }

    func testBackgroundClosesAutomaticViewAtNotificationTimeDespiteQueueDelay() throws {
        let (manager, dependencies, writer, view, queue) = try fixture()
        queue.suspend()
        do {
            try background(manager, dependencies: dependencies, at: 105)
            // A slow downstream callback can outlive the next foreground transition.
            XCTAssertTrue(dependencies.appStateHistory!.recordState("foreground", timeNs: 106_000_000_000))
            (manager as! FTRUMAppStateHistoryDelegate).appStateHistory(
                dependencies.appStateHistory!, didChange: .foregroundOnly,
                time: Date(timeIntervalSince1970: 106))
            XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, true)
        } catch {
            queue.resume()
            throw error
        }
        queue.resume()
        manager.syncProcess()

        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, false)
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.source, "view")
        XCTAssertEqual(event.time, 100_000_000_000)
        XCTAssertEqual(event.updateTime, 105_000_000_000)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 5_000_000_000)
        XCTAssertEqual(event.fields["app_state"] as? String, "foreground")
        XCTAssertEqual(event.fields["is_active"] as? Bool, false)
    }

    func testResourceCompletionUpdatesStoppedViewAndLateStopCannotOverwriteIt() throws {
        let (manager, dependencies, writer, view, queue) = try fixture()
        let resource = FTRUMResourceDataModel(type: .FTRUMDataResourceStart, identifier: "resource")
        resource.time = Date(timeIntervalSince1970: 102)
        try process(resource, manager: manager, queue: queue)
        // Keep another Resource alive so a late Stop still reaches the old Handler.
        let pending = FTRUMResourceDataModel(type: .FTRUMDataResourceStart, identifier: "pending")
        pending.time = Date(timeIntervalSince1970: 103)
        try process(pending, manager: manager, queue: queue)
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, false)

        let resources = try XCTUnwrap(view.value(forKey: "resourceHandlers") as? NSDictionary)
        XCTAssertEqual(resources.count, 2)
        let complete = FTRUMResourceDataModel(type: .FTRUMDataResourceComplete, identifier: "resource")
        complete.time = Date(timeIntervalSince1970: 108)
        complete.tags = [:]
        complete.fields = [:]
        try process(complete, manager: manager, queue: queue)
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.source, "view")
        XCTAssertEqual(event.updateTime, 108_000_000_000)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 8_000_000_000)
        XCTAssertEqual(event.fields["app_state"] as? String, "foreground_and_background")
        let writes = writer.events.count
        let stop = FTRUMViewModel(viewID: "auto-view", viewName: "automatic", viewReferrer: "")
        stop.type = .FTRUMDataViewStop
        stop.time = Date(timeIntervalSince1970: 110)
        stop.fields = ["late": true]
        try process(stop, manager: manager, queue: queue)
        XCTAssertEqual(writer.events.count, writes)
        XCTAssertNil((view.value(forKey: "viewProperty") as? NSDictionary)?["late"])
        let finish = FTRUMResourceDataModel(type: .FTRUMDataResourceComplete, identifier: "pending")
        finish.time = Date(timeIntervalSince1970: 112)
        finish.tags = [:]
        finish.fields = [:]
        try process(finish, manager: manager, queue: queue)
        let final = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(final.updateTime, 112_000_000_000)
        XCTAssertEqual(final.fields["time_spent"] as? Int64, 12_000_000_000)
        XCTAssertEqual(final.fields["view_resource_count"] as? Int, 2)
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        XCTAssertEqual((session.value(forKey: "viewHandlers") as? [NSObject])?.count, 0)
    }

    func testManualViewAndActionAreUnaffectedByBackgroundCommand() throws {
        let (manager, dependencies, writer, view, queue) = try fixture(trackingType: .manual)
        let action = FTRUMActionModel(actionName: "manual-action", actionType: "click")
        action.type = .FTRUMDataStartAction
        action.time = Date(timeIntervalSince1970: 104)
        try process(action, manager: manager, queue: queue)
        let originalAction = try XCTUnwrap(view.value(forKey: "actionHandler") as? NSObject)
        let writes = writer.events.count
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, true)
        XCTAssertTrue((view.value(forKey: "actionHandler") as? NSObject) === originalAction)
        XCTAssertEqual(writer.events.count, writes)
        let stop = FTRUMViewModel(viewID: view.value(forKey: "view_id") as! String,
                                 viewName: "automatic", viewReferrer: "")
        stop.type = .FTRUMDataViewStop
        stop.time = Date(timeIntervalSince1970: 106)
        try process(stop, manager: manager, queue: queue)
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 6_000_000_000)
        XCTAssertEqual(event.fields["app_state"] as? String, "foreground_and_background")
    }

    func testBackgroundCommandClosesAssociatedActionWithoutWaitingForResource() throws {
        let (manager, dependencies, writer, view, queue) = try fixture()
        let action = FTRUMActionModel(actionName: "auto-action", actionType: "click")
        action.type = .FTRUMDataStartAction
        action.time = Date(timeIntervalSince1970: 104.9375)
        try process(action, manager: manager, queue: queue)
        let resource = FTRUMResourceDataModel(type: .FTRUMDataResourceStart, identifier: "resource")
        resource.time = Date(timeIntervalSince1970: 104.96875)
        try process(resource, manager: manager, queue: queue)
        XCTAssertNotNil(view.value(forKey: "actionHandler"))
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        XCTAssertNil(view.value(forKey: "actionHandler"))
        XCTAssertEqual((view.value(forKey: "resourceHandlers") as? NSDictionary)?.count, 1)
        let event = try XCTUnwrap(writer.events.first { $0.source == "action" })
        XCTAssertEqual(event.fields["duration"] as? Int64, 62_500_000)
        XCTAssertEqual(event.fields["action_resource_count"] as? Int, 0)
        XCTAssertNil(event.fields["app_state"])
    }

    func testLaunchActionsDoNotAddAppStateAndKeepRawDuration() throws {
        for type in ["launch_cold", "launch_warm", "launch_hot"] {
            let (manager, _, writer, _, queue) = try fixture()
            let launch = FTRUMLaunchDataModel(duration: 2_000_000_000)
            launch.action_name = type
            launch.action_type = type
            launch.time = Date(timeIntervalSince1970: 102)
            try process(launch, manager: manager, queue: queue)
            let event = try XCTUnwrap(writer.events.first { $0.source == "action" })
            XCTAssertEqual(event.fields["duration"] as? Int64, 2_000_000_000)
            XCTAssertNil(event.fields["app_state"], type)
        }
    }

    func testFallbackViewIsNotClosedEvenWhenItsTrackingTypeIsAutomatic() throws {
        let (manager, dependencies, writer, view, queue) = try fixture()
        let stop = FTRUMViewModel(viewID: "auto-view", viewName: "automatic", viewReferrer: "")
        stop.type = .FTRUMDataViewStop
        stop.time = Date(timeIntervalSince1970: 101)
        try process(stop, manager: manager, queue: queue)
        let action = FTRUMActionModel(actionName: "fallback", actionType: "click")
        action.type = .FTRUMDataAddAction
        action.time = Date(timeIntervalSince1970: 102)
        try process(action, manager: manager, queue: queue)
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let fallback = try XCTUnwrap((session.value(forKey: "viewHandlers") as? [NSObject])?.last)
        XCTAssertFalse(fallback === view)
        XCTAssertEqual(fallback.value(forKey: "fallbackView") as? Bool, true)
        // Exercise the fallback guard independently of its default manual type.
        fallback.setValue(FTRUMViewTrackingType.automatic.rawValue, forKey: "trackingType")
        let writes = writer.events.count
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        XCTAssertEqual(fallback.value(forKey: "isActiveView") as? Bool, true)
        XCTAssertEqual(writer.events.count, writes)
    }

    func testBackgroundControlDoesNotRenewExpiredSession() throws {
        let (manager, dependencies, writer, view, _) = try fixture()
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        try background(manager, dependencies: dependencies, at: 1100)
        manager.syncProcess()
        XCTAssertTrue((manager.value(forKey: "sessionHandler") as? NSObject) === session)
        XCTAssertEqual(session.value(forKey: "lastInteractionTime") as? Date, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, false)
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.updateTime, 1_100_000_000_000)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 1_000_000_000_000)
    }

    func testClockRegressionDoesNotPreventAutomaticViewClosure() throws {
        let (manager, dependencies, writer, view, _) = try fixture()
        try background(manager, dependencies: dependencies, at: 95)
        manager.syncProcess()
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, false)
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.time, 100_000_000_000)
        XCTAssertEqual(event.updateTime, 95_000_000_000)
        XCTAssertEqual(event.fields["app_state"] as? String, "unknown")
        // Preserve the existing non-positive time_spent clamp, not a measured duration.
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 1)
    }

    func testSessionRenewalPreservesAutomaticTrackingType() throws {
        let (manager, dependencies, writer, _, queue) = try fixture()
        let oldSession = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let update = FTRUMDataModel(type: .FTRUMViewPlaceholder,
                                   time: Date(timeIntervalSince1970: 1100))
        try process(update, manager: manager, queue: queue)
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        XCTAssertFalse(session === oldSession)
        let view = try XCTUnwrap((session.value(forKey: "viewHandlers") as? [NSObject])?.last)
        XCTAssertEqual(view.value(forKey: "trackingType") as? UInt, FTRUMViewTrackingType.automatic.rawValue)
        writer.events.removeAll()
        try background(manager, dependencies: dependencies, at: 1105)
        manager.syncProcess()
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 5_000_000_000)
        XCTAssertEqual(event.updateTime, 1_105_000_000_000)
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, false)
    }

    func testStaleBackgroundAndOldViewStopCannotCloseNewViewOrAction() throws {
        let (manager, dependencies, writer, _, queue) = try fixture()
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        XCTAssertTrue(dependencies.appStateHistory!.recordState("foreground", timeNs: 106_000_000_000))
        manager.appState = .run
        let next = FTRUMViewModel(viewID: "new-view", viewName: "new", viewReferrer: "automatic")
        next.type = .FTRUMDataViewStart
        next.time = Date(timeIntervalSince1970: 106)
        next.loading_time = 0
        next.trackingType = .automatic
        try process(next, manager: manager, queue: queue)
        let action = FTRUMActionModel(actionName: "new-action", actionType: "click")
        action.type = .FTRUMDataStartAction
        action.time = Date(timeIntervalSince1970: 106.05)
        try process(action, manager: manager, queue: queue)
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let view = try XCTUnwrap((session.value(forKey: "viewHandlers") as? [NSObject])?.last)
        let originalAction = try XCTUnwrap(view.value(forKey: "actionHandler") as? NSObject)
        let writes = writer.events.count
        let stale = FTRUMAppStateChangeModel(appState: .backgroundOnly,
                                           time: Date(timeIntervalSince1970: 105))
        try process(stale, manager: manager, queue: queue)
        let oldStop = FTRUMViewModel(viewID: "auto-view", viewName: "automatic", viewReferrer: "")
        oldStop.type = .FTRUMDataViewStop
        oldStop.time = Date(timeIntervalSince1970: 106.075)
        try process(oldStop, manager: manager, queue: queue)
        XCTAssertEqual(view.value(forKey: "isActiveView") as? Bool, true)
        XCTAssertTrue((view.value(forKey: "actionHandler") as? NSObject) === originalAction)
        XCTAssertEqual(writer.events.count, writes)
    }

    func testAutomaticViewStillReportsBackgroundDuringLoading() throws {
        let (manager, dependencies, writer, view, _) = try fixture()
        dependencies.appStateHistory = FTRUMAppStateHistory(state: "background", timeNs: 95_000_000_000)
        XCTAssertTrue(dependencies.appStateHistory!.recordState("foreground", timeNs: 99_000_000_000))
        view.setValue(NSNumber(value: Int64(96) * 1_000_000_000), forKey: "loadingStartEpochNs")
        view.setValue(4_000_000_000, forKey: "loading_time")
        try background(manager, dependencies: dependencies, at: 105)
        manager.syncProcess()
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.fields["loading_time"] as? Int64, 4_000_000_000)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 5_000_000_000)
        XCTAssertEqual(event.fields["app_state"] as? String, "foreground_and_background")
    }

    func testAdapterStartForwardsTrackingTypeAndOldAPIStaysManual() throws {
        let (manager, dependencies, writer, _, queue) = try fixture()
        let external = FTExternalDataManager.shared()
        let previous = external.delegate
        external.delegate = manager
        defer { external.delegate = previous }
        external.startView(withName: "adapter-auto", property: ["route": "home"], trackingType: .automatic)
        manager.syncProcess()
        let session = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let auto = try XCTUnwrap((session.value(forKey: "viewHandlers") as? [NSObject])?.last)
        auto.setValue(Date(timeIntervalSince1970: 200), forKey: "viewStartTime")
        auto.setValue(NSNumber(value: Int64(200) * 1_000_000_000), forKey: "loadingStartEpochNs")
        session.setValue(Date(timeIntervalSince1970: 200), forKey: "sessionStartTime")
        session.setValue(Date(timeIntervalSince1970: 200), forKey: "lastInteractionTime")
        writer.events.removeAll()
        try background(manager, dependencies: dependencies, at: 205)
        manager.syncProcess()
        let event = try XCTUnwrap(writer.events.last)
        XCTAssertEqual(event.fields["time_spent"] as? Int64, 5_000_000_000)
        XCTAssertEqual(event.fields["route"] as? String, "home")
        XCTAssertEqual(event.fields["app_state"] as? String, "foreground")
        external.startView(withName: "adapter-manual", property: nil)
        manager.syncProcess()
        let manualSession = try XCTUnwrap(manager.value(forKey: "sessionHandler") as? NSObject)
        let manual = try XCTUnwrap((manualSession.value(forKey: "viewHandlers") as? [NSObject])?.last)
        manual.setValue(Date(timeIntervalSince1970: 206), forKey: "viewStartTime")
        manual.setValue(NSNumber(value: Int64(206) * 1_000_000_000), forKey: "loadingStartEpochNs")
        XCTAssertEqual(manual.value(forKey: "trackingType") as? UInt, FTRUMViewTrackingType.manual.rawValue)
        let stale = FTRUMAppStateChangeModel(appState: .backgroundOnly,
                                           time: Date(timeIntervalSince1970: 210))
        try process(stale, manager: manager, queue: queue)
        XCTAssertEqual(manual.value(forKey: "isActiveView") as? Bool, true)
    }
}
