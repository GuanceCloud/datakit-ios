//
//  GraphicsImage+Reflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CoreGraphics
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension FTGraphicsImage: FTReflection {
    init(from reflector: FTReflector) throws {
        scale = try reflector.descendant("scale")
        orientation = try reflector.descendant("orientation")
        contents = try reflector.descendant("contents")
        if #available(iOS 26, tvOS 26, *) {
            maskColor = reflector.descendantIfPresent(type: Color._ResolvedHDR.self, "maskColor")?.base
        } else {
            maskColor = reflector.descendantIfPresent("maskColor")
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTGraphicsImage.Contents: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("cgImage"), cgImage as CGImage):
            self = .cgImage(cgImage)
        case let (.enum("vectorLayer"), contents):
            self = try .vectorImage(reflector.reflect(contents))
        default:
            self = .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTGraphicsImage.Location: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("bundle"), bundle as Bundle):
            self = .bundle(bundle)
        default:
            self = .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTGraphicsImage.VectorImage: FTReflection {
    init(from reflector: FTReflector) throws {
        location = try reflector.descendant("location")
        name = try reflector.descendant("name")
    }
}

#endif
