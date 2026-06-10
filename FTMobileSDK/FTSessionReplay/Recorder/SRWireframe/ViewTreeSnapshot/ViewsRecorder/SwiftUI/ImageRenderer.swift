//
//  ImageRenderer.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

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
