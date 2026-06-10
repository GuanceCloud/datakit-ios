//
//  Text+Reflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation

@available(iOS 13.0, tvOS 13.0, *)
extension FTStyledTextContentView: FTReflection {
    init(from reflector: FTReflector) throws {
        text = try reflector.descendant("text")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTResolvedStyledTextStringDrawing: FTReflection {
    init(from reflector: FTReflector) throws {
        storage = try reflector.descendant("storage")
    }
}

#endif
