//
//  CGImage+SwiftUI.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CoreGraphics

extension CGImage {
    func ft_isLikelyBundled(scale: CGFloat) -> Bool {
        let maxDimension: CGFloat = 100
        return CGFloat(width) / scale <= maxDimension && CGFloat(height) / scale <= maxDimension
    }
}

#endif
