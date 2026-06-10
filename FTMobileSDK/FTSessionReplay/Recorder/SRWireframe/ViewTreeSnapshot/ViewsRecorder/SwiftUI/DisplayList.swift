//
//  DisplayList.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation
import QuartzCore
import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
struct FTDisplayList {
    struct Identity: Hashable {
        let value: UInt32
    }

    struct Seed: Hashable {
        let value: UInt16
    }

    struct ViewRenderer {
        let renderer: ViewUpdater
    }

    struct ViewUpdater {
        struct ViewCache {
            struct Key: Hashable {
                let id: Index.ID

                init(id: Index.ID) {
                    self.id = id
                }
            }

            let map: [Key: ViewInfo]
        }

        struct ViewInfo {
            let frame: CGRect
            let backgroundColor: CGColor?
            let borderColor: CGColor?
            let borderWidth: CGFloat
            let cornerRadius: CGFloat
            let alpha: CGFloat
            let isHidden: Bool
            let intrinsicContentSize: CGSize
        }

        let viewCache: ViewCache
        let lastList: FTDisplayList.Lazy
    }

    struct Index {
        struct ID: Hashable {
            let identity: Identity

            init(identity: Identity) {
                self.identity = identity
            }
        }
    }

    enum Effect {
        case identify
        case clip(SwiftUI.Path, SwiftUI.FillStyle)
        case filter(FTGraphicsFilter)
        case platformGroup
        case unknown
    }

    struct Content {
        enum Value {
            case shape(SwiftUI.Path, FTResolvedPaint, SwiftUI.FillStyle)
            case text(FTStyledTextContentView, CGSize)
            case platformView
            case color(Color._Resolved)
            case image(FTGraphicsImage)
            case drawing(FTAnyImageRepresentable)
            case unknown
        }

        let seed: Seed
        let value: Value
    }

    struct Item {
        enum Value {
            case effect(Effect, FTDisplayList)
            case content(Content)
            case unknown
        }

        let identity: Identity
        let frame: CGRect
        let value: Value
    }

    let items: [Item]
}

#endif
