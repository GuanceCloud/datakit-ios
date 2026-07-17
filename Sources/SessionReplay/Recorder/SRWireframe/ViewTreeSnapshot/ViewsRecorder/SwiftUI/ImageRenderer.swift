//
//  ImageRenderer.swift
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
final class FTImageRenderer {
    private final class Key: NSObject {
        private let contents: FTAnyImageRepresentable

        init(_ contents: FTAnyImageRepresentable) {
            self.contents = contents
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(contents)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else {
                return false
            }
            return contents == other.contents
        }
    }

    private let cache = NSCache<Key, UIImage>()

    init() {
        cache.countLimit = 20
    }

    func image(for contents: FTAnyImageRepresentable) -> UIImage? {
        let key = Key(contents)
        if let image = cache.object(forKey: key) {
            return image
        }
        guard let image = contents.makeImage() else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}

#endif
