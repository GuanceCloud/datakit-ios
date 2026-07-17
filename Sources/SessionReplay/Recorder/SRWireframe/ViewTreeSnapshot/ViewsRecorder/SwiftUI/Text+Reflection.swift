//
//  Text+Reflection.swift
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
