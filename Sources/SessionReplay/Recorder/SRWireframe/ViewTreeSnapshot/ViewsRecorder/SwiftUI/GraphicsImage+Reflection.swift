//
//  GraphicsImage+Reflection.swift
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
