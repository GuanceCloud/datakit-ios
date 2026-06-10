//
//  Color+Reflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color._Resolved: FTReflection {
    init(from reflector: FTReflector) throws {
        linearRed = try reflector.descendant("linearRed")
        linearGreen = try reflector.descendant("linearGreen")
        linearBlue = try reflector.descendant("linearBlue")
        opacity = try reflector.descendant("opacity")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color._ResolvedHDR: FTReflection {
    init(from reflector: FTReflector) throws {
        base = try reflector.descendant("base")
        _headroom = try reflector.descendant("_headroom")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTColorView: FTReflection {
    init(from reflector: FTReflector) throws {
        color = try reflector.descendant("color")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTResolvedPaint: FTReflection {
    init(from reflector: FTReflector) throws {
        if #available(iOS 26, tvOS 26, *) {
            paint = reflector.descendantIfPresent(type: FTColorView.self, "paint")?.color.base
        } else {
            paint = reflector.descendantIfPresent("paint")
        }
    }
}

#endif
