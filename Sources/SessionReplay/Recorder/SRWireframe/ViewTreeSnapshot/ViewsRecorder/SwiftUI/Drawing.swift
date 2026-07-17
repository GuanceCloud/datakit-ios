//
//  Drawing.swift
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

import CoreGraphics
import Foundation
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
struct FTDrawing: FTImageRepresentable {
    private enum Constants {
        static let cls: AnyClass? = NSClassFromString("RBMovedDisplayListContents")
        static let renderInContextOptions = NSSelectorFromString("renderInContext:options:")
        static let boundingRectKey = "boundingRect"
        static let rasterizationScaleKey = "rasterizationscale"
        static let maxSize = 1_024
    }

    private let contents: NSObject
    private let origin: CGPoint
    private let scale: CGFloat

    private var bounds: CGRect? {
        contents.value(forKey: Constants.boundingRectKey) as? CGRect
    }

    init?(contents: NSObject, origin: CGPoint, scale: CGFloat = UIScreen.main.scale) {
        guard
            let cls = Constants.cls,
            type(of: contents).isSubclass(of: cls),
            contents.responds(to: Constants.renderInContextOptions)
        else {
            return nil
        }
        self.contents = contents
        self.origin = origin
        self.scale = scale
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(contents.hash)
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(scale)
    }

    static func == (lhs: FTDrawing, rhs: FTDrawing) -> Bool {
        lhs.contents.isEqual(rhs.contents) && lhs.origin == rhs.origin && lhs.scale == rhs.scale
    }

    func makeImage() -> UIImage? {
        guard let bounds else {
            return nil
        }
        let width = Int((bounds.width + 1.5) * scale)
        let height = Int((bounds.height + 1.5) * scale)
        guard width > 0, height > 0, width <= Constants.maxSize, height <= Constants.maxSize else {
            return nil
        }
        guard let bitmapContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        bitmapContext.translateBy(x: 0, y: CGFloat(height) + origin.y)
        bitmapContext.scaleBy(x: scale, y: -scale)
        contents.perform(Constants.renderInContextOptions, with: bitmapContext, with: [Constants.rasterizationScaleKey: scale])
        return bitmapContext.makeImage().map { UIImage(cgImage: $0, scale: scale, orientation: .up) }
    }
}

#endif
