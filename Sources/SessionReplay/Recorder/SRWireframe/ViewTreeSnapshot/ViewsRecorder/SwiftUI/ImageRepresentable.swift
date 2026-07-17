//
//  ImageRepresentable.swift
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
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
protocol FTImageRepresentable: Hashable {
    func makeImage() -> UIImage?
}

@available(iOS 13.0, tvOS 13.0, *)
struct FTAnyImageRepresentable: FTImageRepresentable {
    private let wrapped: AnyHashable
    private let make: () -> UIImage?

    init<T>(_ imageRepresentable: T) where T: FTImageRepresentable {
        wrapped = AnyHashable(imageRepresentable)
        make = imageRepresentable.makeImage
    }

    func makeImage() -> UIImage? {
        make()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(wrapped)
    }

    static func == (lhs: FTAnyImageRepresentable, rhs: FTAnyImageRepresentable) -> Bool {
        lhs.wrapped == rhs.wrapped
    }
}

#endif
