//
//  Color.swift
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
