//
//  ShapeResourceBuilder.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation
import SwiftUI
import UIKit

@available(iOS 13.0, *)
final class FTShapeResourceBuilder {
    private final class PathKey: NSObject {
        private let path: SwiftUI.Path

        init(_ path: SwiftUI.Path) {
            self.path = path
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(path.description)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? PathKey else {
                return false
            }
            return path == other.path
        }
    }

    private final class ResourceKey: NSObject {
        private let path: SwiftUI.Path
        private let color: FTResolvedPaint
        private let fillStyle: SwiftUI.FillStyle
        private let size: CGSize

        init(_ path: SwiftUI.Path, _ color: FTResolvedPaint, _ fillStyle: SwiftUI.FillStyle, _ size: CGSize) {
            self.path = path
            self.color = color
            self.fillStyle = fillStyle
            self.size = size
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(path.description)
            hasher.combine(color)
            hasher.combine(fillStyle.isEOFilled)
            hasher.combine(size.width)
            hasher.combine(size.height)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? ResourceKey else {
                return false
            }
            return path == other.path && color == other.color && fillStyle == other.fillStyle && size == other.size
        }
    }

    private let pathCache = NSCache<PathKey, NSString>()
    private let resourceCache = NSCache<ResourceKey, FTShapeResource>()

    init() {
        pathCache.countLimit = 25
        resourceCache.countLimit = 50
    }

    func shapeResource(for path: SwiftUI.Path, color: FTResolvedPaint, fillStyle: SwiftUI.FillStyle, size: CGSize) -> FTShapeResource {
        let key = ResourceKey(path, color, fillStyle, size)
        if let resource = resourceCache.object(forKey: key) {
            return resource
        }

        let fillColor = color.paint.map { $0.uiColor.cgColor.ft_hexString } ?? "#000000FF"
        let fillRule = fillStyle.isEOFilled ? "evenodd" : "nonzero"
        let resource = FTShapeResource(
            svgString: """
            <svg width="\(size.width.ft_svgString)" height="\(size.height.ft_svgString)" xmlns="http://www.w3.org/2000/svg">
              <path d="\(pathData(for: path))" fill="\(fillColor)" fill-rule="\(fillRule)"/>
            </svg>
            """
        )
        resourceCache.setObject(resource, forKey: key)
        return resource
    }

    private func pathData(for path: SwiftUI.Path) -> String {
        let key = PathKey(path)
        if let pathData = pathCache.object(forKey: key) {
            return pathData as String
        }
        let pathData = path.ft_svgString
        pathCache.setObject(pathData as NSString, forKey: key)
        return pathData
    }
}

#endif
