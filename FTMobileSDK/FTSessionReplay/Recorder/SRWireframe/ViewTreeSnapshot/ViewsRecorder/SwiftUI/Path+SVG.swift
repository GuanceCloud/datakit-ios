//
//  Path+SVG.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CoreGraphics
import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Path {
    var ft_svgString: String {
        var d = ""
        forEach { element in
            switch element {
            case let .move(to):
                d += "M \(to.ft_svgString) "
            case let .line(to):
                d += "L \(to.ft_svgString) "
            case let .quadCurve(to, control):
                d += "Q \(control.ft_svgString) \(to.ft_svgString) "
            case let .curve(to, control1, control2):
                d += "C \(control1.ft_svgString) \(control2.ft_svgString) \(to.ft_svgString) "
            case .closeSubpath:
                d += "Z "
            }
        }
        return d.trimmingCharacters(in: .whitespaces)
    }
}

extension CGPoint {
    var ft_svgString: String {
        "\(x.ft_svgString) \(y.ft_svgString)"
    }
}

extension CGFloat {
    var ft_svgString: String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), self)
    }
}

#endif
