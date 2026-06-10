//
//  GraphicsImage.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CoreGraphics
import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
struct FTGraphicsImage {
    enum Contents {
        case cgImage(CGImage)
        case vectorImage(VectorImage)
        case unknown
    }

    enum Location {
        case bundle(Bundle)
        case unknown
    }

    struct VectorImage {
        let location: Location
        let name: String

        var bundle: Bundle? {
            if case let .bundle(bundle) = location {
                return bundle
            }
            return nil
        }
    }

    let scale: CGFloat
    let orientation: SwiftUI.Image.Orientation
    let contents: Contents
    let maskColor: SwiftUI.Color._Resolved?
    
    var uiImageOrientation: UIImage.Orientation {
        UIImage.Orientation(orientation)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension UIImage.Orientation {
    init(_ orientation: SwiftUI.Image.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

#endif
