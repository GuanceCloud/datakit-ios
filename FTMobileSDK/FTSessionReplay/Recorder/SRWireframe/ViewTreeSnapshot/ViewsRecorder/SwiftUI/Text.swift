//
//  Text.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
struct FTStyledTextContentView {
    let text: FTResolvedStyledTextStringDrawing
}

@available(iOS 13.0, tvOS 13.0, *)
struct FTResolvedStyledTextStringDrawing {
    let storage: NSAttributedString
}

#endif
