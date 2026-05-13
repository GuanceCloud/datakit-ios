//
//  FTSwiftUIViewNameExtractor.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/7.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if canImport(UIKit) && canImport(SwiftUI)

import Foundation
import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
@objc(FTSwiftUIViewNameExtractor)
final class FTSwiftUIViewNameExtractor: NSObject {
    private protocol TopLevelReflector {
        func descendant(_ path: [Node]) -> Any?
    }

    private struct MirrorReflector: TopLevelReflector {
        let subject: Any

        func descendant(_ path: [Node]) -> Any? {
            path.reduce(Optional.some(subject as Any)) { current, node in
                guard let current else {
                    return nil
                }
                return Self.child(named: node.rawValue, in: current)
            }
        }

        private static func child(named key: String, in subject: Any) -> Any? {
            let unwrapped = unwrap(subject) ?? subject
            var mirror: Mirror? = Mirror(reflecting: unwrapped)
            while let current = mirror {
                if let child = current.children.first(where: { $0.label == key }) {
                    return unwrap(child.value) ?? child.value
                }
                mirror = current.superclassMirror
            }
            return nil
        }

        private static func unwrap(_ value: Any) -> Any? {
            let mirror = Mirror(reflecting: value)
            guard mirror.displayStyle == .optional else {
                return nil
            }
            return mirror.children.first?.value
        }
    }

    private enum Node: String {
        case host
        case rootView = "_rootView"
        case root
        case storage
        case view
        case content
        case list
        case item
        case type

        static let hostingBase: [Node] = [.host, .rootView]
        static let navigationBase: [Node] = [.host, .rootView, .storage, .view, .content, .content, .content]
        static let sheetBase: [Node] = [.host, .rootView, .storage, .view, .content]
    }

    private enum Path {
        case hostingControllerRootView
        case hostingControllerModifiedContent
        case hostingControllerBase
        case navigationStackContent
        case navigationStackAnyView
        case navigationStackBase
        case sheetContent

        var components: [Node] {
            switch self {
            case .hostingControllerRootView:
                return Node.hostingBase + [.content, .storage, .view, .content, .storage, .view, .content, .content]
            case .hostingControllerModifiedContent:
                return Node.hostingBase + [.content, .storage, .view]
            case .hostingControllerBase:
                return Node.hostingBase
            case .navigationStackContent:
                return Node.navigationBase + [.content, .list, .item, .type]
            case .navigationStackAnyView:
                return Node.navigationBase + [.root]
            case .navigationStackBase:
                return Node.navigationBase
            case .sheetContent:
                return Node.sheetBase
            }
        }

        func traverse(with reflector: TopLevelReflector) -> Any? {
            reflector.descendant(components)
        }
    }

    private enum ControllerType {
        case hostingController
        case navigationStackHostingController
        case modal
        case unknown

        init(className: String) {
            if className.hasPrefix("_TtGC7SwiftUI19UIHostingController") || className.contains("UIHostingController") {
                self = .hostingController
            } else if className.contains("Navigation") {
                self = .navigationStackHostingController
            } else if className.hasPrefix("_TtGC7SwiftUI29PresentationHostingController") ||
                        className.contains("PresentationHostingController") ||
                        className.contains("SheetHostingController") {
                self = .modal
            } else {
                self = .unknown
            }
        }
    }

    private static let genericTypePattern = try? NSRegularExpression(pattern: #"<(?:[^,>]*,\s+)?([^<>,]+?)>"#)
    private static let hostingControllerPattern = try? NSRegularExpression(pattern: "UIHostingController<([A-Za-z0-9_]+)>")
    private static let navigationStackPattern = try? NSRegularExpression(pattern: "NavigationStackHostingController<([A-Za-z0-9_]+)>")

    private let createReflector: (Any) -> TopLevelReflector

    override convenience init() {
        self.init(reflectorFactory: { subject in
            MirrorReflector(subject: subject)
        })
    }

    private init(reflectorFactory: @escaping (Any) -> TopLevelReflector) {
        self.createReflector = reflectorFactory
        super.init()
    }

    @objc(extractNameFromViewController:)
    func extractName(from viewController: UIViewController) -> String? {
        let bundleName = Bundle(for: type(of: viewController)).bundleURL.lastPathComponent
        if bundleName == "UIKitCore.framework" || bundleName == "UIKit.framework" {
            return nil
        }

        let className = NSStringFromClass(type(of: viewController))
        if shouldSkip(viewController: viewController, className: className) {
            return nil
        }

        let controllerType = ControllerType(className: className)
        let reflector = createReflector(viewController)

        return extractViewName(
            from: viewController,
            controllerType: controllerType,
            with: reflector
        )
    }

    private func extractViewName(
        from viewController: UIViewController,
        controllerType: ControllerType,
        with reflector: TopLevelReflector
    ) -> String? {
        switch controllerType {
        case .hostingController:
            if let output = Path.hostingControllerRootView.traverse(with: reflector) {
                return extractViewName(from: typeDescription(of: output))
            }
            if let output = Path.hostingControllerModifiedContent.traverse(with: reflector) {
                return extractViewName(from: typeDescription(of: output))
            }
            if Path.hostingControllerBase.traverse(with: reflector) != nil {
                return extractFallbackViewName(from: typeDescription(of: viewController))
            }

        case .navigationStackHostingController:
            if let output = Path.navigationStackContent.traverse(with: reflector) {
                return extractViewName(from: typeDescription(of: output))
            }
            if Path.navigationStackAnyView.traverse(with: reflector) != nil {
                return extractFallbackViewName(from: typeDescription(of: viewController))
            }
            if let output = Path.navigationStackBase.traverse(with: reflector) {
                return extractViewName(from: typeDescription(of: output))
            }

        case .modal:
            if let output = Path.sheetContent.traverse(with: reflector) {
                return extractViewName(from: typeDescription(of: output))
            }

        case .unknown:
            break
        }

        return nil
    }

    private func extractViewName(from input: String) -> String? {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        if let match = Self.genericTypePattern?.firstMatch(in: input, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: input) {
            return String(input[matchRange])
        }

        if input.hasSuffix(".Type") {
            return String(input.dropLast(5))
        }

        if input.range(of: "^[A-Z][A-Za-z0-9_]*View$", options: .regularExpression) != nil {
            return input
        }

        return nil
    }

    private func extractFallbackViewName(from description: String) -> String {
        if description == "NavigationStackHostingController<AnyView>" || description == "UIHostingController<AnyView>" {
            return description
        }

        if let viewName = extractGenericViewName(from: description, using: Self.hostingControllerPattern) {
            return viewName
        }

        if let viewName = extractGenericViewName(from: description, using: Self.navigationStackPattern) {
            return viewName
        }

        return description.contains("UIHostingController") ? "AutoTracked_HostingController_Fallback" : "AutoTracked_NavigationStackController_Fallback"
    }

    private func extractGenericViewName(from description: String, using pattern: NSRegularExpression?) -> String? {
        let range = NSRange(description.startIndex..<description.endIndex, in: description)
        guard let match = pattern?.firstMatch(in: description, options: [], range: range),
              let matchRange = Range(match.range(at: 1), in: description) else {
            return nil
        }
        return String(description[matchRange])
    }

    private func shouldSkip(viewController: UIViewController, className: String) -> Bool {
        if className == "SwiftUI.UIKitTabBarController" ||
            className == "_TtGC7SwiftUI19UIHostingControllerVVS_7TabItem8RootView_" ||
            className == "SwiftUI.TabHostingController" ||
            className == "SwiftUI.NotifyingMulticolumnSplitViewController" {
            return true
        }

        return viewController is UINavigationController
    }

    private func typeDescription(of object: Any) -> String {
        String(describing: Swift.type(of: object))
    }
}

#endif
