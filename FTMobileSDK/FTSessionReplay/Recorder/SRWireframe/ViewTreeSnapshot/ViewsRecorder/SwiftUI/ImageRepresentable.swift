//
//  ImageRepresentable.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

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
