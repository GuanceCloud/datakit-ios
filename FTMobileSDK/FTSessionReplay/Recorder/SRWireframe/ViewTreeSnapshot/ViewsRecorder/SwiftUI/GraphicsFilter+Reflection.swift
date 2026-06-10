//
//  GraphicsFilter+Reflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension FTGraphicsFilter: FTReflection {
    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("colorMultiply"), color):
            if #available(iOS 26, tvOS 26, *) {
                self = try .colorMultiply(reflector.reflect(type: Color._ResolvedHDR.self, color).base)
            } else {
                self = try .colorMultiply(reflector.reflect(color))
            }
        default:
            self = .unknown
        }
    }
}

#endif
