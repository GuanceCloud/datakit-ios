//
//  FTSwiftUIRUMViewModifier.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/12.
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

#if canImport(UIKit) && canImport(SwiftUI)

import Foundation
import SwiftUI

/// A SwiftUI view wrapper that reports RUM view lifecycle events.
@available(iOS 13.0, tvOS 13.0, *)
public struct FTRUMTrackedView<Content: View>: View {
    let name: String
    let property: [String: Any]?
    let content: () -> Content

    @State private var identity = UUID().uuidString
    @State private var loadStartTime = DispatchTime.now().uptimeNanoseconds
    @State private var didReportLoadTime = false

    /// Creates a wrapper that reports the lifecycle of its content as a RUM view.
    ///
    /// - Parameters:
    ///   - name: Name reported for the RUM view.
    ///   - property: Optional custom properties for the RUM view.
    ///   - content: Content whose appearance and disappearance are tracked.
    public init(
        name: String,
        property: [String: Any]? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.property = property
        self.content = content
    }

    /// The wrapped SwiftUI content with RUM lifecycle reporting applied.
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
