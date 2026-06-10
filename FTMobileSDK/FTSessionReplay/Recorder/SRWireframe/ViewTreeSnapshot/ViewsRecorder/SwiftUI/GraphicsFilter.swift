//
//  GraphicsFilter.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
enum FTGraphicsFilter {
    case colorMultiply(Color._Resolved)
    case unknown
}

#endif
