//
//  Color.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation
import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color {
    struct _Resolved: Hashable {
        let linearRed: Float
        let linearGreen: Float
        let linearBlue: Float
        let opacity: Float

        var uiColor: UIColor {
            UIColor(
                red: CGFloat(linearRed),
                green: CGFloat(linearGreen),
                blue: CGFloat(linearBlue),
                alpha: CGFloat(opacity)
            )
        }
    }

    struct _ResolvedHDR {
        let base: _Resolved
        let _headroom: Float
    }
}

@available(iOS 13.0, tvOS 13.0, *)
struct FTColorView {
    let color: SwiftUI.Color._ResolvedHDR
}

@available(iOS 13.0, tvOS 13.0, *)
struct FTResolvedPaint: Hashable {
    let paint: SwiftUI.Color._Resolved?
}

#endif
