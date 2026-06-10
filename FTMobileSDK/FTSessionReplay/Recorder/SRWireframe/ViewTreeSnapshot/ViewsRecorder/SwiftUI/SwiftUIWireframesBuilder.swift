//
//  SwiftUIWireframesBuilder.swift
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

private enum FTSwiftUIWireframeKind {
    static let shape = 0
    static let text = 1
    static let image = 2
    static let placeholder = 3
}

private enum FTImagePrivacy {
    static let maskNonBundledOnly = 0
    static let maskAll = 1
    static let maskNone = 2
}

@available(iOS 13.0, *)
struct FTSwiftUIWireframesBuilder {
    struct Output {
        var wireframes: [FTSwiftUIWireframePayload] = []
    }

    struct Context {
        var frame: CGRect
        var clip: CGRect
        var tintColor: Color._Resolved?

        func convert(frame: CGRect) -> CGRect {
            frame.offsetBy(dx: self.frame.minX, dy: self.frame.minY)
        }

        mutating func convert(to frame: CGRect) {
            self.frame = self.frame.offsetBy(dx: frame.minX, dy: frame.minY)
        }
    }

    let wireframeID: Int64
    let renderer: FTDisplayList.ViewUpdater
    let imageRenderer: FTImageRenderer
    let shapeResourceBuilder: FTShapeResourceBuilder
    let textPrivacyLevel: Int
    let imagePrivacyLevel: Int
    let rootFrame: CGRect
    let rootClip: CGRect
    let rootAlpha: CGFloat
    let rootBackgroundColor: CGColor?
    let rootBorderColor: CGColor?
    let rootBorderWidth: CGFloat
    let rootCornerRadius: CGFloat

    func build() -> FTSwiftUIRecordingResult {
        var output = Output()
        output.wireframes.append(makeRootWireframe())
        do {
            let list = try renderer.lastList.reflect()
            let context = Context(frame: rootFrame, clip: rootClip, tintColor: nil)
            output.wireframes.append(contentsOf: buildWireframes(items: list.items, context: context))
        } catch {
        }
        return FTSwiftUIRecordingResult(wireframes: output.wireframes, resources: [])
    }

    private func makeRootWireframe() -> FTSwiftUIWireframePayload {
        makeShape(
            id: wireframeID,
            frame: rootFrame,
            clip: rootClip,
            borderColor: rootBorderColor,
            borderWidth: rootBorderWidth,
            backgroundColor: rootBackgroundColor,
            cornerRadius: rootCornerRadius,
            opacity: rootAlpha
        )
    }

    private func buildWireframes(items: [FTDisplayList.Item], context: Context) -> [FTSwiftUIWireframePayload] {
        items.reduce([]) { wireframes, item in
            switch item.value {
            case let .effect(effect, list):
                return wireframes + effectWireframes(item: item, effect: effect, list: list, context: context)
            case let .content(content):
                return wireframes + contentWireframes(item: item, content: content, context: context)
            case .unknown:
                return wireframes
            }
        }
    }

    private func effectWireframes(item: FTDisplayList.Item, effect: FTDisplayList.Effect, list: FTDisplayList, context: Context) -> [FTSwiftUIWireframePayload] {
        var context = context
        context.frame = context.convert(frame: item.frame)

        switch effect {
        case let .clip(path, _):
            let clip = context.convert(frame: path.boundingRect)
            context.clip = context.clip.intersection(clip)
        case let .filter(.colorMultiply(color)):
            context.tintColor = color
        case .platformGroup:
            let key = FTDisplayList.ViewUpdater.ViewCache.Key(id: .init(identity: item.identity))
            if let viewInfo = renderer.viewCache.map[key] {
                context.convert(to: viewInfo.frame)
            }
        case .identify, .filter, .unknown:
            break
        }

        return buildWireframes(items: list.items, context: context)
    }

    private func contentWireframes(item: FTDisplayList.Item, content: FTDisplayList.Content, context: Context) -> [FTSwiftUIWireframePayload] {
        contentWireframe(item: item, content: content, context: context).map { [$0] } ?? []
    }

    private func contentWireframe(item: FTDisplayList.Item, content: FTDisplayList.Content, context: Context) -> FTSwiftUIWireframePayload? {
        let viewInfo = renderer.viewCache.map[.init(id: .init(identity: item.identity))]
        let id = wireframeID(for: content.seed)
        let frame = context.convert(frame: item.frame)

        switch content.value {
        case let .shape(path, color, fillStyle):
            if imagePrivacyLevel == FTImagePrivacy.maskAll {
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Image")
            }
            let resource = shapeResourceBuilder.shapeResource(for: path, color: color, fillStyle: fillStyle, size: item.frame.size)
            return makeImage(id: id, resource: resource, frame: frame, clip: context.clip)

        case let .text(view, _):
            let storage = view.text.storage
            let style: NSParagraphStyle?
            let foregroundColor: UIColor?
            let font: UIFont?
            if storage.length > 0 {
                style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                foregroundColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
                font = storage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            } else {
                style = nil
                foregroundColor = nil
                font = nil
            }
            return makeText(
                id: id,
                frame: frame,
                clip: context.clip,
                text: storage.string,
                paragraphStyle: style,
                textColor: foregroundColor?.cgColor,
                font: font
            )

        case .color:
            return makeShape(
                id: id,
                frame: frame,
                clip: context.clip,
                borderColor: viewInfo?.borderColor,
                borderWidth: viewInfo?.borderWidth ?? 0,
                backgroundColor: viewInfo?.backgroundColor,
                cornerRadius: viewInfo?.cornerRadius ?? 0,
                opacity: viewInfo?.alpha ?? rootAlpha
            )

        case let .image(resolvedImage):
            switch resolvedImage.contents {
            case let .cgImage(cgImage):
                if shouldRecord(graphicsImage: resolvedImage) {
                    let image = UIImage(cgImage: cgImage, scale: resolvedImage.scale, orientation: resolvedImage.uiImageOrientation)
                    guard image.size.width > 0, image.size.height > 0 else {
                        return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
                    }
                    return makeImage(id: id, image: image, tintColor: resolvedImage.maskColor?.uiColor, frame: frame, clip: context.clip)
                }
                let label = imagePrivacyLevel == FTImagePrivacy.maskNonBundledOnly ? "Content Image" : "Image"
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: label)

            case let .vectorImage(vectorImage):
                if shouldRecord(graphicsImage: resolvedImage),
                   let bundle = vectorImage.bundle,
                   let image = UIImage(named: vectorImage.name, in: bundle, compatibleWith: nil) {
                    guard image.size.width > 0, image.size.height > 0 else {
                        return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
                    }
                    return makeImage(id: id, image: image, tintColor: resolvedImage.maskColor?.uiColor, frame: frame, clip: context.clip)
                }
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Image")

            case .unknown:
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
            }

        case let .drawing(drawing):
            if imagePrivacyLevel == FTImagePrivacy.maskAll {
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Image")
            }
            guard let image = imageRenderer.image(for: drawing) else {
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
            }
            guard image.size.width > 0, image.size.height > 0 else {
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
            }
            return makeImage(id: id, image: image, tintColor: context.tintColor?.uiColor, frame: frame, clip: context.clip)

        case .platformView:
            return nil

        case .unknown:
            return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported SwiftUI component")
        }
    }

    private func wireframeID(for seed: FTDisplayList.Seed) -> Int64 {
        var generator = FTXoshiroRandomNumberGenerator(seed: seed.value)
        return Int64.random(in: 0..<Int64.max, using: &generator)
    }

    private func shouldRecord(graphicsImage: FTGraphicsImage) -> Bool {
        switch imagePrivacyLevel {
        case FTImagePrivacy.maskNone:
            return true
        case FTImagePrivacy.maskNonBundledOnly:
            switch graphicsImage.contents {
            case let .cgImage(cgImage):
                return cgImage.ft_isLikelyBundled(scale: graphicsImage.scale)
            case .vectorImage:
                return true
            case .unknown:
                return false
            }
        case FTImagePrivacy.maskAll:
            return false
        default:
            return false
        }
    }

    private func makeShape(id: Int64, frame: CGRect, clip: CGRect, borderColor: CGColor?, borderWidth: CGFloat, backgroundColor: CGColor?, cornerRadius: CGFloat, opacity: CGFloat) -> FTSwiftUIWireframePayload {
        FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.shape,
            identifier: id,
            frame: frame,
            clip: clip,
            backgroundColor: backgroundColor?.ft_hexString,
            borderColor: borderColor?.ft_hexString,
            borderWidth: borderWidth,
            cornerRadius: cornerRadius,
            opacity: opacity
        )
    }

    private func makeText(id: Int64, frame: CGRect, clip: CGRect, text: String, paragraphStyle: NSParagraphStyle?, textColor: CGColor?, font: UIFont?) -> FTSwiftUIWireframePayload {
        FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.text,
            identifier: id,
            frame: frame,
            clip: clip,
            text: text,
            textColor: textColor?.ft_hexString ?? "#FF0000FF",
            fontSize: font?.pointSize ?? 10,
            textAlignment: paragraphStyle?.alignment ?? .left,
            lineBreakMode: paragraphStyle?.lineBreakMode ?? .byWordWrapping
        )
    }

    private func makeImage(id: Int64, resource: FTShapeResource, frame: CGRect, clip: CGRect) -> FTSwiftUIWireframePayload {
        let payload = resource.makePayload()
        return FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.image,
            identifier: id,
            frame: frame,
            clip: clip,
            resourceIdentifier: payload.identifier,
            mimeType: payload.mimeType,
            resourceData: payload.data
        )
    }

    private func makeImage(id: Int64, image: UIImage, tintColor: UIColor?, frame: CGRect, clip: CGRect) -> FTSwiftUIWireframePayload {
        FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.image,
            identifier: id,
            frame: frame,
            clip: clip,
            mimeType: "image/png",
            image: image,
            tintColor: tintColor
        )
    }

    private func makePlaceholder(id: Int64, frame: CGRect, clip: CGRect, label: String) -> FTSwiftUIWireframePayload {
        FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.placeholder,
            identifier: id,
            frame: frame,
            clip: clip,
            label: label
        )
    }
}

#endif
