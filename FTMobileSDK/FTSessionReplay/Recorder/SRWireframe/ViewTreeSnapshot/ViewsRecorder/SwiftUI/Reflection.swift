//
//  Reflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation

protocol FTReflection {
    init(from reflector: FTReflector) throws
}

enum FTReflectionDisplayStyle: Equatable {
    case `struct`
    case `class`
    case `enum`(String)
    case tuple
    case `nil`
    case opaque
}

#endif
