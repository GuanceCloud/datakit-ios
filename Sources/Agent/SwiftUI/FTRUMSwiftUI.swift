//
//  FTRUMSwiftUI.swift
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if canImport(UIKit)

import Foundation

#if canImport(_GuanceSDKSwiftSupport)
@_spi(Private) import _GuanceSDKSwiftSupport
#endif

/// APIs for manually reporting RUM events from SwiftUI views.
public enum FTRUMSwiftUI {
    /// Tracks a SwiftUI tap action without adding any extra gesture recognizer.
    ///
    /// Prefer calling this inside a `Button` action or `.onTapGesture` closure when the target view is in a
    /// `List`, `NavigationLink`, scroll view, or already uses custom gestures.
    public static func trackTapAction(name: String, property: [String: Any]? = nil) {
        FTSwiftUIRUMActionBridge.handler?.notifySwiftUITapAction(name: name, property: property)
    }
}

#endif
