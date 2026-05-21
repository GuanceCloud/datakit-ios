//
//  FTSwiftUIRUMViewModifier.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/12.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if canImport(UIKit) && canImport(SwiftUI)

import Foundation
import SwiftUI

@objc(FTSwiftUIRUMViewHandling)
@_spi(Private)
public protocol FTSwiftUIRUMViewHandling: AnyObject {
    @objc(notifyOnAppearWithIdentity:name:property:loadTime:)
    func notifyOnAppear(identity: String, name: String, property: [String: Any]?, loadTime: NSNumber)

    @objc(notifyOnDisappearWithIdentity:)
    func notifyOnDisappear(identity: String)
}

@objc(FTSwiftUIRUMViewBridge)
@_spi(Private)
public final class FTSwiftUIRUMViewBridge: NSObject {
    private final class WeakBox {
        weak var value: FTSwiftUIRUMViewHandling?
    }

    private static let handlerBox = WeakBox()

    @objc public class var handler: FTSwiftUIRUMViewHandling? {
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            return handlerBox.value
        }
        set {
            objc_sync_enter(self)
            handlerBox.value = newValue
            objc_sync_exit(self)
        }
    }
}

@objc(FTSwiftUIRUMActionHandling)
@_spi(Private)
public protocol FTSwiftUIRUMActionHandling: AnyObject {
    @objc(notifySwiftUITapActionWithName:property:)
    func notifySwiftUITapAction(name: String, property: [String: Any]?)
}

@objc(FTSwiftUIRUMActionBridge)
@_spi(Private)
public final class FTSwiftUIRUMActionBridge: NSObject {
    private final class WeakBox {
        weak var value: FTSwiftUIRUMActionHandling?
    }

    private static let handlerBox = WeakBox()

    @objc public class var handler: FTSwiftUIRUMActionHandling? {
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            return handlerBox.value
        }
        set {
            objc_sync_enter(self)
            handlerBox.value = newValue
            objc_sync_exit(self)
        }
    }
}

public enum FTRUMSwiftUI {
    /// Tracks a SwiftUI tap action without adding any extra gesture recognizer.
    ///
    /// Prefer calling this inside a `Button` action or `.onTapGesture` closure when the target view is in a
    /// `List`, `NavigationLink`, scroll view, or already uses custom gestures.
    public static func trackTapAction(name: String, property: [String: Any]? = nil) {
        FTSwiftUIRUMActionBridge.handler?.notifySwiftUITapAction(name: name, property: property)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
public struct FTRUMTrackedView<Content: View>: View {
    let name: String
    let property: [String: Any]?
    let content: () -> Content

    @State private var identity = UUID().uuidString
    @State private var loadStartTime = DispatchTime.now().uptimeNanoseconds
    @State private var didReportLoadTime = false

    public init(
        name: String,
        property: [String: Any]? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.property = property
        self.content = content
    }

    public var body: some View {
        content()
            .onAppear {
                FTSwiftUIRUMViewBridge.handler?.notifyOnAppear(
                    identity: identity,
                    name: name,
                    property: property,
                    loadTime: loadTimeForAppear()
                )
            }
            .onDisappear {
                FTSwiftUIRUMViewBridge.handler?.notifyOnDisappear(identity: identity)
            }
    }

    private func loadTimeForAppear() -> NSNumber {
        if didReportLoadTime {
            return NSNumber(value: 0)
        }
        didReportLoadTime = true
        let now = DispatchTime.now().uptimeNanoseconds
        return NSNumber(value: now > loadStartTime ? now - loadStartTime : 0)
    }
}

#if os(iOS)
@available(iOS 13.0, *)
private struct FTRUMTapActionModifier: ViewModifier {
    let name: String
    let property: [String: Any]?
    let count: Int

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture(count: count).onEnded {
                FTRUMSwiftUI.trackTapAction(name: name, property: property)
            }
        )
    }
}
#endif

@available(iOS 13.0, tvOS 13.0, *)
public extension View {
    /// Manually tracks this SwiftUI view as a RUM View using SwiftUI's public `onAppear` and `onDisappear` lifecycle.
    ///
    /// Example:
    /// ```swift
    /// SomeView()
    ///     .ftTrackRUMView(name: "Home")
    /// ```
    func ftTrackRUMView(name: String, property: [String: Any]? = nil) -> some View {
        FTRUMTrackedView(name: name, property: property) {
            self
        }
    }
}

#if os(iOS)
@available(iOS 13.0, *)
public extension View {
    /// Tracks this SwiftUI view as a RUM tap action by adding a simultaneous `TapGesture`.
    ///
    /// This is a convenience API. For `List`, `NavigationLink`, scrollable content, or views with custom gesture
    /// handling, prefer calling `FTRUMSwiftUI.trackTapAction(name:property:)` from the existing action closure.
    func ftTrackRUMTapAction(name: String, property: [String: Any]? = nil, count: Int = 1) -> some View {
        modifier(FTRUMTapActionModifier(name: name, property: property, count: count))
    }
}
#endif

#endif
