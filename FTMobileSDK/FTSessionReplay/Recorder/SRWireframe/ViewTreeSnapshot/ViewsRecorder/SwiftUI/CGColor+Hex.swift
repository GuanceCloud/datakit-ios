//
//  CGColor+Hex.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CoreGraphics
import Foundation

extension CGColor {
    var ft_hexString: String {
        let converted = converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ) ?? self
        guard let components = converted.components else {
            return "#00000000"
        }
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if components.count >= 4 {
            red = components[0]
            green = components[1]
            blue = components[2]
            alpha = components[3]
        } else if components.count >= 2 {
            red = components[0]
            green = components[0]
            blue = components[0]
            alpha = components[1]
        } else {
            return "#00000000"
        }
        return String(
            format: "#%02X%02X%02X%02X",
            Int(max(0, min(1, red)) * 255),
            Int(max(0, min(1, green)) * 255),
            Int(max(0, min(1, blue)) * 255),
            Int(max(0, min(1, alpha)) * 255)
        )
    }
}

#endif
