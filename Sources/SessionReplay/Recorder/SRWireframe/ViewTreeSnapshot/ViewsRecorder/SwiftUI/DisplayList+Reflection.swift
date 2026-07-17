//
//  DisplayList+Reflection.swift
//  SessionReplay
//
//  Created by hulilei on 2026/6/8.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been adapted in Swift with project-specific changes.
 */

#if os(iOS)

import Foundation
import QuartzCore
import SwiftUI
import UIKit

private extension CGColor {
    var safeCast: CGColor? {
        guard CFGetTypeID(self) == CGColor.typeID else { return nil }
        return self
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList: FTReflection {
    init(from reflector: FTReflector) throws {
        items = try reflector.descendant("items")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Identity: FTReflection {
    init(from reflector: FTReflector) throws {
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Seed: FTReflection {
    init(from reflector: FTReflector) throws {
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.ViewRenderer: FTReflection {
    init(from reflector: FTReflector) throws {
        renderer = try reflector.descendant("renderer")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.ViewUpdater: FTReflection {
    init(from reflector: FTReflector) throws {
        viewCache = try reflector.descendant("viewCache")
        lastList = try reflector.descendant("lastList")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.ViewUpdater.ViewCache: FTReflection {
    init(from reflector: FTReflector) throws {
        map = try reflector.descendant("map")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.ViewUpdater.ViewCache.Key: FTReflection {
    init(from reflector: FTReflector) throws {
        id = try reflector.descendant("id")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.ViewUpdater.ViewInfo: FTReflection {
    init(from reflector: FTReflector) throws {
        let layer = try reflector.descendant(type: CALayer.self, "layer")
        if let view = reflector.descendantIfPresent(type: UIView.self, "view") {
            let container = try reflector.descendant(type: UIView.self, "container")
            frame = container.convert(container.bounds, to: view)
            alpha = view.alpha
            intrinsicContentSize = container.intrinsicContentSize
        } else {
            let container = try reflector.descendant(type: CALayer.self, "container")
            frame = container.convert(container.bounds, to: layer)
            alpha = CGFloat(layer.opacity)
            intrinsicContentSize = container.preferredFrameSize()
        }
        backgroundColor = layer.backgroundColor?.safeCast
        borderColor = layer.borderColor?.safeCast
        borderWidth = layer.borderWidth
        cornerRadius = layer.cornerRadius
        isHidden = layer.isHidden
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Index.ID: FTReflection {
    init(from reflector: FTReflector) throws {
        identity = try reflector.descendant("identity")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Effect: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case (.enum("identity"), _):
            self = .identify
        case let (.enum("clip"), tuple as (SwiftUI.Path, SwiftUI.FillStyle, Any)):
            self = .clip(tuple.0, tuple.1)
        case let (.enum("filter"), filter):
            self = try .filter(reflector.reflect(filter))
        case (.enum("platformGroup"), _):
            self = .platformGroup
        default:
            self = .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Content: FTReflection {
    init(from reflector: FTReflector) throws {
        seed = try reflector.descendant("seed")
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Content.Value: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("shape"), tuple as (SwiftUI.Path, Any, SwiftUI.FillStyle)):
            self = try .shape(tuple.0, reflector.reflect(tuple.1), tuple.2)
        case let (.enum("text"), tuple as (Any, CGSize)):
            self = try .text(reflector.reflect(tuple.0), tuple.1)
        case (.enum("platformView"), _):
            self = .platformView
        case let (.enum("image"), image):
            self = try .image(reflector.reflect(image))
        case let (.enum("drawing"), (contents, origin, _) as (NSObject, CGPoint, Any)):
            if let drawing = FTDrawing(contents: contents, origin: origin) {
                self = .drawing(FTAnyImageRepresentable(drawing))
            } else {
                self = .unknown
            }
        case let (.enum("color"), color):
            if #available(iOS 26, tvOS 26, *) {
                self = try .color(reflector.reflect(type: FTColorView.self, color).color.base)
            } else {
                self = try .color(reflector.reflect(color))
            }
        default:
            self = .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Item: FTReflection {
    init(from reflector: FTReflector) throws {
        identity = try reflector.descendant("identity")
        frame = try reflector.descendant("frame")
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Item.Value: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("effect"), tuple as (Any, Any)):
            self = try .effect(reflector.reflect(tuple.0), reflector.reflect(tuple.1))
        case let (.enum("content"), value):
            self = try .content(reflector.reflect(value))
        default:
            self = .unknown
        }
    }
}

#endif
