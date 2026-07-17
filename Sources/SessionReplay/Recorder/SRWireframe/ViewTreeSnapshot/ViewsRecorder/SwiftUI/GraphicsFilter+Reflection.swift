//
//  GraphicsFilter+Reflection.swift
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
