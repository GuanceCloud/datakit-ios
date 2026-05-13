//
//  FTSwiftUIReflection.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/4/29.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import CommonCrypto
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

private enum FTTextPrivacy {
    static let maskAll = 2
}

@available(iOS 13.0, *)
@objc(FTSwiftUIRecordingResult)
@_spi(Private)
public final class FTSwiftUIRecordingResult: NSObject {
    @objc let wireframes: [FTSwiftUIWireframePayload]
    @objc let resources: [FTSwiftUIResourcePayload]

    @objc init(wireframes: [FTSwiftUIWireframePayload], resources: [FTSwiftUIResourcePayload]) {
        self.wireframes = wireframes
        self.resources = resources
        super.init()
    }
}

@available(iOS 13.0, *)
@objc(FTSwiftUIRenderer)
@_spi(Private)
public final class FTSwiftUIRenderer: NSObject {
    fileprivate let renderer: FTDisplayList.ViewUpdater

    fileprivate init(renderer: FTDisplayList.ViewUpdater) {
        self.renderer = renderer
        super.init()
    }
}

@available(iOS 13.0, *)
@objc(FTSwiftUIRecordingBuilder)
@_spi(Private)
public final class FTSwiftUIRecordingBuilder: NSObject {
    private let builder: FTSwiftUIWireframesBuilder
    private let lock = NSLock()
    private var result: FTSwiftUIRecordingResult?

    fileprivate init(builder: FTSwiftUIWireframesBuilder) {
        self.builder = builder
        super.init()
    }

    @objc(build)
    public func build() -> FTSwiftUIRecordingResult? {
        lock.lock()
        defer { lock.unlock() }

        if let result {
            return result
        }

        let result = builder.build()
        self.result = result
        return result
    }
}

@available(iOS 13.0, *)
@objc(FTSwiftUIWireframePayload)
@_spi(Private)
public final class FTSwiftUIWireframePayload: NSObject {
    @objc let kind: Int
    @objc let identifier: Int64
    @objc let frame: CGRect
    @objc let clip: CGRect
    @objc let label: String?
    @objc let text: String?
    @objc let textColor: String?
    @objc let fontSize: CGFloat
    @objc let textAlignment: NSTextAlignment
    @objc let lineBreakMode: NSLineBreakMode
    @objc let backgroundColor: String?
    @objc let borderColor: String?
    @objc let borderWidth: CGFloat
    @objc let cornerRadius: CGFloat
    @objc let opacity: CGFloat
    @objc let resourceIdentifier: String?
    @objc let mimeType: String?

    @objc init(
        kind: Int,
        identifier: Int64,
        frame: CGRect,
        clip: CGRect,
        label: String? = nil,
        text: String? = nil,
        textColor: String? = nil,
        fontSize: CGFloat = 0,
        textAlignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        backgroundColor: String? = nil,
        borderColor: String? = nil,
        borderWidth: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        opacity: CGFloat = 1,
        resourceIdentifier: String? = nil,
        mimeType: String? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.frame = frame
        self.clip = clip
        self.label = label
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
        self.textAlignment = textAlignment
        self.lineBreakMode = lineBreakMode
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.resourceIdentifier = resourceIdentifier
        self.mimeType = mimeType
        super.init()
    }
}

@available(iOS 13.0, *)
@objc(FTSwiftUIResourcePayload)
@_spi(Private)
public final class FTSwiftUIResourcePayload: NSObject {
    @objc let identifier: String
    @objc let mimeType: String
    @objc let data: Data

    @objc init(identifier: String, mimeType: String, data: Data) {
        self.identifier = identifier
        self.mimeType = mimeType
        self.data = data
        super.init()
    }
}

@available(iOS 13.0, *)
@objc(FTSwiftUIRecordingAttributes)
@_spi(Private)
public final class FTSwiftUIRecordingAttributes: NSObject {
    @objc dynamic var frame: CGRect = .zero
    @objc dynamic var clip: CGRect = .zero
    @objc dynamic var alpha: CGFloat = 1
    @objc dynamic var backgroundColor: UIColor?
    @objc dynamic var borderColor: UIColor?
    @objc dynamic var borderWidth: CGFloat = 0
    @objc dynamic var cornerRadius: CGFloat = 0
    @objc dynamic var textPrivacy: Int = 0
    @objc dynamic var imagePrivacy: Int = 0
    @objc dynamic var wireframeID: Int64 = 0
}

@available(iOS 13.0, *)
@objc(FTSwiftUIReflectionRecording)
@_spi(Private)
public protocol FTSwiftUIReflectionRecording: NSObjectProtocol {
    @objc(makeRecordingAttributes)
    func makeRecordingAttributes() -> FTSwiftUIRecordingAttributes

    @objc(rendererForHostingView:)
    func renderer(hostingView: UIView) -> FTSwiftUIRenderer?

    @objc(recordingBuilderForRenderer:attributes:)
    func recordingBuilder(renderer: FTSwiftUIRenderer, attributes: FTSwiftUIRecordingAttributes) -> FTSwiftUIRecordingBuilder?
}

@available(iOS 13.0, *)
@objc(FTSwiftUIReflectionBridge)
@_spi(Private)
public final class FTSwiftUIReflectionBridge: NSObject, FTSwiftUIReflectionRecording {
    private let imageRenderer = FTImageRenderer()
    private let shapeResourceBuilder = FTShapeResourceBuilder()

    private static var rendererKeyPath: [String] {
        if #available(iOS 26, tvOS 26, *) {
            return ["_base", "viewGraph", "renderer"]
        } else if #available(iOS 18.1, tvOS 18.1, *) {
            return ["_base", "renderer"]
        } else {
            return ["renderer"]
        }
    }

    @objc(makeRecordingAttributes)
    public func makeRecordingAttributes() -> FTSwiftUIRecordingAttributes {
        FTSwiftUIRecordingAttributes()
    }

    @objc(rendererForHostingView:)
    public func renderer(hostingView: UIView) -> FTSwiftUIRenderer? {
        guard let rendererObject = extractObject(from: hostingView, keyPath: Self.rendererKeyPath) else {
            return nil
        }

        do {
            return try FTSwiftUIRenderer(renderer: makeRenderer(from: rendererObject))
        } catch {
            return nil
        }
    }

    @objc(recordingBuilderForRenderer:attributes:)
    public func recordingBuilder(renderer: FTSwiftUIRenderer, attributes: FTSwiftUIRecordingAttributes) -> FTSwiftUIRecordingBuilder? {
        let builder = FTSwiftUIWireframesBuilder(
            wireframeID: attributes.wireframeID,
            renderer: renderer.renderer,
            imageRenderer: imageRenderer,
            shapeResourceBuilder: shapeResourceBuilder,
            textPrivacyLevel: attributes.textPrivacy,
            imagePrivacyLevel: attributes.imagePrivacy,
            rootFrame: attributes.frame,
            rootClip: attributes.clip,
            rootAlpha: attributes.alpha,
            rootBackgroundColor: attributes.backgroundColor,
            rootBorderColor: attributes.borderColor,
            rootBorderWidth: attributes.borderWidth,
            rootCornerRadius: attributes.cornerRadius
        )

        return FTSwiftUIRecordingBuilder(builder: builder)
    }

    private func makeRenderer(from rendererObject: AnyObject) throws -> FTDisplayList.ViewUpdater {
        let reflector = FTReflector(subject: rendererObject)
        do {
            let renderer = try FTDisplayList.ViewRenderer(from: reflector).renderer
            return renderer
        } catch {
            let wrapperError = error
            do {
                return try FTDisplayList.ViewUpdater(from: reflector)
            } catch {
                throw FTReflector.Error.rendererUnavailable(
                    rendererType: FTReflector.typeName(of: rendererObject),
                    availableLabels: FTReflector.availableLabels(in: rendererObject),
                    wrapperError: String(describing: wrapperError),
                    directError: String(describing: error)
                )
            }
        }
    }

    private func extractObject(from subject: AnyObject, keyPath: [String]) -> AnyObject? {
        var current = subject
        for component in keyPath {
            guard
                let ivar = class_getInstanceVariable(type(of: current), component),
                let next = object_getIvar(current, ivar) as? AnyObject
            else {
                return nil
            }
            current = next
        }
        return current
    }
}

@available(iOS 13.0, *)
private struct FTSwiftUIWireframesBuilder {
    struct Output {
        var wireframes: [FTSwiftUIWireframePayload] = []
        var resourcesByIdentifier: [String: FTSwiftUIResourcePayload] = [:]

        mutating func append(_ resource: FTSwiftUIResourcePayload) {
            resourcesByIdentifier[resource.identifier] = resource
        }
    }

    struct Context {
        var frame: CGRect
        var clip: CGRect
        var tintColor: Color._Resolved?
        let resourceCollector: FTResourceCollector

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
    let rootBackgroundColor: UIColor?
    let rootBorderColor: UIColor?
    let rootBorderWidth: CGFloat
    let rootCornerRadius: CGFloat

    func build() -> FTSwiftUIRecordingResult {
        var output = Output()
        output.wireframes.append(makeRootWireframe())
        do {
            let list = try renderer.lastList.reflect()
            let resourceCollector = FTResourceCollector()
            let context = Context(frame: rootFrame, clip: rootClip, tintColor: nil, resourceCollector: resourceCollector)
            output.wireframes.append(contentsOf: buildWireframes(items: list.items, context: context))
            output.resourcesByIdentifier = resourceCollector.resourcesByIdentifier
        } catch {
        }
        return FTSwiftUIRecordingResult(
            wireframes: output.wireframes,
            resources: Array(output.resourcesByIdentifier.values)
        )
    }

    private func makeRootWireframe() -> FTSwiftUIWireframePayload {
        makeShape(
            id: wireframeID,
            frame: rootFrame,
            clip: rootClip,
            borderColor: rootBorderColor?.cgColor,
            borderWidth: rootBorderWidth,
            backgroundColor: rootBackgroundColor?.cgColor,
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
            context.resourceCollector.append(resource)
            return makeImage(id: id, resource: resource, frame: frame, clip: context.clip)

        case let .text(view, _):
            let storage = view.text.storage
            let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            let foregroundColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
            let font = storage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
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
                    guard let resource = FTSwiftUIResourcePayload.imageResource(image: image, tintColor: resolvedImage.maskColor?.uiColor) else {
                        return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
                    }
                    context.resourceCollector.append(resource)
                    return makeImage(id: id, resource: resource, frame: frame, clip: context.clip)
                }
                let label = imagePrivacyLevel == FTImagePrivacy.maskNonBundledOnly ? "Content Image" : "Image"
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: label)

            case let .vectorImage(vectorImage):
                if shouldRecord(graphicsImage: resolvedImage),
                   let bundle = vectorImage.bundle,
                   let image = UIImage(named: vectorImage.name, in: bundle, compatibleWith: nil) {
                    guard let resource = FTSwiftUIResourcePayload.imageResource(image: image, tintColor: resolvedImage.maskColor?.uiColor) else {
                        return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
                    }
                    context.resourceCollector.append(resource)
                    return makeImage(id: id, resource: resource, frame: frame, clip: context.clip)
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
            guard let resource = FTSwiftUIResourcePayload.imageResource(image: image, tintColor: context.tintColor?.uiColor) else {
                return makePlaceholder(id: id, frame: frame, clip: context.clip, label: "Unsupported image type")
            }
            context.resourceCollector.append(resource)
            return makeImage(id: id, resource: resource, frame: frame, clip: context.clip)

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

    private func makeImage(id: Int64, resource: FTSwiftUIResourcePayload, frame: CGRect, clip: CGRect) -> FTSwiftUIWireframePayload {
        FTSwiftUIWireframePayload(
            kind: FTSwiftUIWireframeKind.image,
            identifier: id,
            frame: frame,
            clip: clip,
            resourceIdentifier: resource.identifier,
            mimeType: resource.mimeType
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

@available(iOS 13.0, tvOS 13.0, *)
private final class FTResourceCollector {
    private(set) var resourcesByIdentifier: [String: FTSwiftUIResourcePayload] = [:]

    func append(_ resource: FTSwiftUIResourcePayload) {
        resourcesByIdentifier[resource.identifier] = resource
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTDisplayList {
    struct Identity: Hashable {
        let value: UInt32
    }

    struct Seed: Hashable {
        let value: UInt16
    }

    struct ViewRenderer: FTReflection {
        let renderer: ViewUpdater

        init(from reflector: FTReflector) throws {
            renderer = try reflector.descendant("renderer")
        }
    }

    struct ViewUpdater: FTReflection {
        struct ViewCache: FTReflection {
            struct Key: Hashable, FTReflection {
                let id: Index.ID

                init(id: Index.ID) {
                    self.id = id
                }

                init(from reflector: FTReflector) throws {
                    id = try reflector.descendant("id")
                }
            }

            let map: [Key: ViewInfo]

            init(from reflector: FTReflector) throws {
                map = try reflector.descendantDictionary("map")
            }
        }

        struct ViewInfo: FTReflection {
            let frame: CGRect
            let backgroundColor: CGColor?
            let borderColor: CGColor?
            let borderWidth: CGFloat
            let cornerRadius: CGFloat
            let alpha: CGFloat
            let isHidden: Bool
            let intrinsicContentSize: CGSize

            init(from reflector: FTReflector) throws {
                let layer: CALayer = try reflector.descendant("layer")
                if let view: UIView = reflector.descendantIfPresent("view") {
                    let container: UIView = try reflector.descendant("container")
                    frame = container.convert(container.bounds, to: view)
                    alpha = view.alpha
                    intrinsicContentSize = container.intrinsicContentSize
                } else {
                    let container: CALayer = try reflector.descendant("container")
                    frame = container.convert(container.bounds, to: layer)
                    alpha = CGFloat(layer.opacity)
                    intrinsicContentSize = container.preferredFrameSize()
                }
                backgroundColor = layer.backgroundColor
                borderColor = layer.borderColor
                borderWidth = layer.borderWidth
                cornerRadius = layer.cornerRadius
                isHidden = layer.isHidden
            }
        }

        let viewCache: ViewCache
        let lastList: FTReflector.Lazy<FTDisplayList>

        init(from reflector: FTReflector) throws {
            viewCache = try reflector.descendant("viewCache")
            lastList = try reflector.descendant("lastList")
        }
    }

    struct Index {
        struct ID: Hashable, FTReflection {
            let identity: Identity

            init(identity: Identity) {
                self.identity = identity
            }

            init(from reflector: FTReflector) throws {
                identity = try reflector.descendant("identity")
            }
        }
    }

    enum Effect: FTReflection {
        case identify
        case clip(SwiftUI.Path, SwiftUI.FillStyle)
        case filter(FTGraphicsFilter)
        case platformGroup
        case unknown

        init(from reflector: FTReflector) throws {
            switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
            case (.enum("identity"), _):
                self = .identify
            case let (.enum("clip"), tuple as (SwiftUI.Path, SwiftUI.FillStyle, Any)):
                self = .clip(tuple.0, tuple.1)
            case let (.enum("filter"), filter):
                self = try .filter(reflector.reflect(filter))
            case (.enum("platformGroup"), _):
                self = .platformGroup
            default:
                self = .unknown
            }
        }
    }

    struct Content: FTReflection {
        enum Value: FTReflection {
            case shape(SwiftUI.Path, FTResolvedPaint, SwiftUI.FillStyle)
            case text(FTStyledTextContentView, CGSize)
            case platformView
            case color(Color._Resolved)
            case image(FTGraphicsImage)
            case drawing(FTAnyImageRepresentable)
            case unknown

            init(from reflector: FTReflector) throws {
                do {
                    switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
                    case let (.enum("shape"), tuple as (SwiftUI.Path, Any, SwiftUI.FillStyle)):
                        self = try .shape(tuple.0, reflector.reflect(tuple.1), tuple.2)
                    case let (.enum("text"), tuple as (Any, CGSize)):
                        self = try .text(reflector.reflect(tuple.0), tuple.1)
                    case (.enum("platformView"), _):
                        self = .platformView
                    case let (.enum("image"), image):
                        self = try .image(reflector.reflect(image))
                    case let (.enum("drawing"), (contents, origin, _) as (NSObject, CGPoint, Any)):
                        if let drawing = FTDrawing(contents: contents, origin: origin) {
                            self = .drawing(FTAnyImageRepresentable(drawing))
                        } else {
                            self = .unknown
                        }
                    case let (.enum("color"), color):
                        if #available(iOS 26, tvOS 26, *) {
                            self = try .color(reflector.reflect(type: FTColorView.self, color).color.base)
                        } else {
                            self = try .color(reflector.reflect(color))
                        }
                    default:
                        self = .unknown
                    }
                } catch {
                    self = .unknown
                }
            }
        }

        let seed: Seed
        let value: Value

        init(from reflector: FTReflector) throws {
            seed = try reflector.descendant("seed")
            do {
                value = try reflector.descendant("value")
            } catch {
                value = .unknown
            }
        }
    }

    struct Item: FTReflection {
        enum Value: FTReflection {
            case effect(Effect, FTDisplayList)
            case content(Content)
            case unknown

            init(from reflector: FTReflector) throws {
                do {
                    switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
                    case let (.enum("effect"), tuple as (Any, Any)):
                        self = try .effect(reflector.reflect(tuple.0), reflector.reflect(tuple.1))
                    case let (.enum("content"), value):
                        self = try .content(reflector.reflect(value))
                    default:
                        self = .unknown
                    }
                } catch {
                    self = .unknown
                }
            }
        }

        let identity: Identity
        let frame: CGRect
        let value: Value

        init(from reflector: FTReflector) throws {
            identity = try reflector.descendant("identity")
            frame = try reflector.descendant("frame")
            do {
                value = try reflector.descendant("value")
            } catch {
                value = .unknown
            }
        }
    }

    let items: [Item]
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList: FTReflection {
    init(from reflector: FTReflector) throws {
        items = try reflector.descendantArray("items")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Identity: FTReflection {
    init(from reflector: FTReflector) throws {
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension FTDisplayList.Seed: FTReflection {
    init(from reflector: FTReflector) throws {
        value = try reflector.descendant("value")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTStyledTextContentView: FTReflection {
    let text: FTResolvedStyledTextStringDrawing

    init(from reflector: FTReflector) throws {
        text = try reflector.descendant("text")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTResolvedStyledTextStringDrawing: FTReflection {
    let storage: NSAttributedString

    init(from reflector: FTReflector) throws {
        storage = try reflector.descendant("storage")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private enum FTGraphicsFilter: FTReflection {
    case colorMultiply(Color._Resolved)
    case unknown

    init(from reflector: FTReflector) throws {
        switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
        case let (.enum("colorMultiply"), color):
            if #available(iOS 26, tvOS 26, *) {
                self = try .colorMultiply(reflector.reflect(type: Color._ResolvedHDR.self, color).base)
            } else {
                self = try .colorMultiply(reflector.reflect(color))
            }
        default:
            self = .unknown
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTGraphicsImage: FTReflection {
    enum Contents: FTReflection {
        case cgImage(CGImage)
        case vectorImage(VectorImage)
        case unknown

        init(from reflector: FTReflector) throws {
            switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
            case let (.enum("cgImage"), cgImage as CGImage):
                self = .cgImage(cgImage)
            case let (.enum("vectorLayer"), contents):
                self = try .vectorImage(reflector.reflect(contents))
            default:
                self = .unknown
            }
        }
    }

    enum Location: FTReflection {
        case bundle(Bundle)
        case unknown

        init(from reflector: FTReflector) throws {
            switch (reflector.displayStyle, reflector.descendantIfPresent(0)) {
            case let (.enum("bundle"), bundle as Bundle):
                self = .bundle(bundle)
            default:
                self = .unknown
            }
        }
    }

    struct VectorImage: FTReflection {
        let location: Location
        let name: String
        var bundle: Bundle? {
            if case let .bundle(bundle) = location { return bundle }
            return nil
        }

        init(from reflector: FTReflector) throws {
            location = try reflector.descendant("location")
            name = try reflector.descendant("name")
        }
    }

    let scale: CGFloat
    let orientation: SwiftUI.Image.Orientation
    let contents: Contents
    let maskColor: Color._Resolved?

    var uiImageOrientation: UIImage.Orientation {
        UIImage.Orientation(orientation)
    }

    init(from reflector: FTReflector) throws {
        scale = try reflector.descendant("scale")
        orientation = try reflector.descendant("orientation")
        contents = try reflector.descendant("contents")
        if #available(iOS 26, tvOS 26, *) {
            maskColor = reflector.descendantIfPresent(type: Color._ResolvedHDR.self, "maskColor")?.base
        } else {
            maskColor = reflector.descendantIfPresent("maskColor")
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color {
    struct _Resolved: Hashable, FTReflection {
        let linearRed: Float
        let linearGreen: Float
        let linearBlue: Float
        let opacity: Float

        var uiColor: UIColor {
            UIColor(
                red: CGFloat(linearRed),
                green: CGFloat(linearGreen),
                blue: CGFloat(linearBlue),
                alpha: CGFloat(opacity)
            )
        }

        init(from reflector: FTReflector) throws {
            linearRed = try reflector.descendant("linearRed")
            linearGreen = try reflector.descendant("linearGreen")
            linearBlue = try reflector.descendant("linearBlue")
            opacity = try reflector.descendant("opacity")
        }
    }

    struct _ResolvedHDR: FTReflection {
        let base: _Resolved
        let _headroom: Float

        init(from reflector: FTReflector) throws {
            base = try reflector.descendant("base")
            _headroom = try reflector.descendant("_headroom")
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTColorView: FTReflection {
    let color: SwiftUI.Color._ResolvedHDR

    init(from reflector: FTReflector) throws {
        color = try reflector.descendant("color")
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTResolvedPaint: Hashable, FTReflection {
    let paint: SwiftUI.Color._Resolved?

    init(from reflector: FTReflector) throws {
        if #available(iOS 26, tvOS 26, *) {
            paint = reflector.descendantIfPresent(type: FTColorView.self, "paint")?.color.base
        } else {
            paint = reflector.descendantIfPresent("paint")
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private protocol FTImageRepresentable: Hashable {
    func makeImage() -> UIImage?
}

@available(iOS 13.0, tvOS 13.0, *)
private struct FTAnyImageRepresentable: FTImageRepresentable {
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

@available(iOS 13.0, tvOS 13.0, *)
private struct FTDrawing: FTImageRepresentable {
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

@available(iOS 13.0, tvOS 13.0, *)
private final class FTImageRenderer {
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

@available(iOS 13.0, *)
private final class FTShapeResourceBuilder {
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
    private let resourceCache = NSCache<ResourceKey, FTSwiftUIResourcePayload>()

    init() {
        pathCache.countLimit = 25
        resourceCache.countLimit = 50
    }

    func shapeResource(for path: SwiftUI.Path, color: FTResolvedPaint, fillStyle: SwiftUI.FillStyle, size: CGSize) -> FTSwiftUIResourcePayload {
        let key = ResourceKey(path, color, fillStyle, size)
        if let resource = resourceCache.object(forKey: key) {
            return resource
        }

        let fillColor = color.paint.map { $0.uiColor.cgColor.ft_hexString } ?? "#000000FF"
        let fillRule = fillStyle.isEOFilled ? "evenodd" : "nonzero"
        let data = Data(
            """
            <svg width="\(size.width.ft_svgString)" height="\(size.height.ft_svgString)" xmlns="http://www.w3.org/2000/svg">
              <path d="\(pathData(for: path))" fill="\(fillColor)" fill-rule="\(fillRule)"/>
            </svg>
            """
            .utf8
        )
        let resource = FTSwiftUIResourcePayload(identifier: data.ft_md5String, mimeType: "image/svg+xml", data: data)
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

protocol FTReflection {
    init(from reflector: FTReflector) throws
}

enum FTReflectionDisplayStyle: Equatable {
    case `struct`
    case `class`
    case `enum`(String)
    case tuple
    case optional
    case nilValue
    case opaque
}

struct FTReflector {
    struct Lazy<T> where T: FTReflection {
        let reflect: () throws -> T
    }

    enum Error: Swift.Error, CustomStringConvertible {
        case notFound(path: [String], subjectType: String, availableLabels: [String])
        case typeMismatch(path: [String], expectedType: String, actualType: String, subjectType: String)
        case rendererUnavailable(rendererType: String, availableLabels: [String], wrapperError: String, directError: String)

        var description: String {
            switch self {
            case let .notFound(path, subjectType, availableLabels):
                return "notFound(path: \(path.joined(separator: ".")), subject: \(subjectType), available: \(availableLabels))"
            case let .typeMismatch(path, expectedType, actualType, subjectType):
                return "typeMismatch(path: \(path.joined(separator: ".")), expected: \(expectedType), actual: \(actualType), subject: \(subjectType))"
            case let .rendererUnavailable(rendererType, availableLabels, wrapperError, directError):
                return "rendererUnavailable(type: \(rendererType), available: \(availableLabels), wrapperError: \(wrapperError), directError: \(directError))"
            }
        }
    }

    let subject: Any
    let mirror: Mirror

    private var subjectType: String {
        Self.typeName(of: subject)
    }

    private var availableLabels: [String] {
        Self.availableLabels(in: subject)
    }

    var displayStyle: FTReflectionDisplayStyle {
        switch mirror.displayStyle {
        case .class:
            return .class
        case .struct:
            return .struct
        case .enum:
            return .enum(enumCaseName(subject: subject, mirror: mirror))
        case .tuple:
            return .tuple
        case .optional:
            return .optional
        default:
            return .opaque
        }
    }

    init(subject: Any) {
        let unwrapped = FTReflector.unwrap(subject) ?? subject
        self.subject = unwrapped
        self.mirror = Mirror(reflecting: unwrapped)
    }

    func descendantIfPresent(_ first: Any, _ rest: Any...) -> Any? {
        descendant(paths: [first] + rest)
    }

    func descendantIfPresent<T>(_ first: Any, _ rest: Any...) -> T? {
        descendant(paths: [first] + rest) as? T
    }

    func descendantIfPresent<T>(type: T.Type = T.self, _ first: Any, _ rest: Any...) -> T? where T: FTReflection {
        do {
            return try descendant(type: type, first, rest)
        } catch {
            return nil
        }
    }

    func descendant<T>(_ first: Any, _ rest: Any...) throws -> T {
        let paths = [first] + rest
        guard let value = descendant(paths: paths) else {
            throw Error.notFound(path: Self.pathLabels(paths), subjectType: subjectType, availableLabels: availableLabels)
        }
        guard let typed = value as? T else {
            throw Error.typeMismatch(
                path: Self.pathLabels(paths),
                expectedType: String(reflecting: T.self),
                actualType: Self.typeName(of: value),
                subjectType: subjectType
            )
        }
        return typed
    }

    func descendant<T>(_ first: Any, _ rest: Any...) throws -> T where T: FTReflection {
        let paths = [first] + rest
        guard let value = descendant(paths: paths) else {
            throw Error.notFound(path: Self.pathLabels(paths), subjectType: subjectType, availableLabels: availableLabels)
        }
        return try reflect(type: T.self, value)
    }

    func descendant<T>(type: T.Type = T.self, _ first: Any, _ rest: [Any]) throws -> T where T: FTReflection {
        try descendant(type: type, [first] + rest)
    }

    func descendant<T>(type: T.Type = T.self, _ first: Any, _ rest: Any...) throws -> T where T: FTReflection {
        try descendant(type: type, [first] + rest)
    }

    func descendant<T>(type: T.Type = T.self, _ paths: [Any]) throws -> T where T: FTReflection {
        guard let value = descendant(paths: paths) else {
            throw Error.notFound(path: Self.pathLabels(paths), subjectType: subjectType, availableLabels: availableLabels)
        }
        return try reflect(type: type, value)
    }

    func descendantArray<Element>(_ first: Any, _ rest: Any...) throws -> [Element] where Element: FTReflection {
        let paths = [first] + rest
        guard let value = descendant(paths: paths) else {
            throw Error.notFound(path: Self.pathLabels(paths), subjectType: subjectType, availableLabels: availableLabels)
        }
        guard let subject = value as? [Any] else {
            throw Error.typeMismatch(
                path: Self.pathLabels(paths),
                expectedType: String(reflecting: [Any].self),
                actualType: Self.typeName(of: value),
                subjectType: subjectType
            )
        }
        return subject.compactMap { try? reflect($0) }
    }

    func descendantDictionary<Key, Value>(_ first: Any, _ rest: Any...) throws -> [Key: Value] where Key: FTReflection, Key: Hashable, Value: FTReflection {
        let paths = [first] + rest
        guard let subject = descendant(paths: paths) else {
            throw Error.notFound(path: Self.pathLabels(paths), subjectType: subjectType, availableLabels: availableLabels)
        }
        return try reflectDictionary(subject, path: Self.pathLabels(paths))
    }

    func reflect<T>(type: T.Type = T.self, _ subject: Any?) throws -> T where T: FTReflection {
        try T(from: FTReflector(subject: subject as Any))
    }

    private func descendant(paths: [Any]) -> Any? {
        var current: Any? = subject
        for path in paths {
            guard let value = current else {
                return nil
            }
            current = FTReflector.child(in: value, path: path)
        }
        return current.flatMap { FTReflector.unwrap($0) ?? $0 }
    }

    private static func child(in subject: Any, path: Any) -> Any? {
        let mirror = Mirror(reflecting: unwrap(subject) ?? subject)
        if let index = path as? Int {
            let children = Array(mirror.children)
            if index < children.count {
                return children[index].value
            }
        }
        if let key = path as? String {
            var current: Mirror? = mirror
            while let mirrorToSearch = current {
                if let child = mirrorToSearch.children.first(where: { $0.label == key }) {
                    return child.value
                }
                current = mirrorToSearch.superclassMirror
            }
        }
        return nil
    }

    private static func unwrap(_ any: Any) -> Any? {
        let mirror = Mirror(reflecting: any)
        guard mirror.displayStyle == .optional else {
            return nil
        }
        return mirror.children.first?.value
    }

    static func typeName(of value: Any) -> String {
        String(reflecting: Swift.type(of: value))
    }

    static func availableLabels(in value: Any) -> [String] {
        let mirror = Mirror(reflecting: unwrap(value) ?? value)
        var labels: [String] = []
        var current: Mirror? = mirror
        while let mirrorToSearch = current {
            labels.append(
                contentsOf: mirrorToSearch.children.enumerated().map { index, child in
                    child.label ?? "#\(index)"
                }
            )
            current = mirrorToSearch.superclassMirror
        }
        return labels
    }

    private static func pathLabels(_ paths: [Any]) -> [String] {
        paths.map { String(describing: $0) }
    }

    private func enumCaseName(subject: Any, mirror: Mirror) -> String {
        if let label = mirror.children.first?.label {
            return label
        }
        let description = String(describing: subject)
        return description.split(separator: "(", maxSplits: 1).first.map(String.init) ?? description
    }

    private func reflectDictionary<Key, Value>(_ subject: Any, path: [String]) throws -> [Key: Value] where Key: FTReflection, Key: Hashable, Value: FTReflection {
        if let dictionary = subject as? [AnyHashable: Any] {
            return dictionary.reduce(into: [:]) { result, element in
                guard let key = try? reflect(type: Key.self, element.key.base),
                      let value = try? reflect(type: Value.self, element.value) else {
                    return
                }
                result[key] = value
            }
        }

        let mirror = Mirror(reflecting: subject)
        guard mirror.displayStyle == .dictionary else {
            throw Error.typeMismatch(
                path: path,
                expectedType: String(reflecting: [AnyHashable: Any].self),
                actualType: Self.typeName(of: subject),
                subjectType: Self.typeName(of: subject)
            )
        }

        return mirror.children.reduce(into: [:]) { result, child in
            let pair = Mirror(reflecting: child.value)
            let values = Array(pair.children)
            guard values.count == 2,
                  let key = try? reflect(type: Key.self, values[0].value),
                  let value = try? reflect(type: Value.self, values[1].value) else {
                return
            }
            result[key] = value
        }
    }
}

extension FTReflector.Lazy: FTReflection {
    init(from reflector: FTReflector) throws {
        reflect = { try T(from: reflector) }
    }
}

private struct FTXoshiroRandomNumberGenerator: RandomNumberGenerator {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    init<T>(seed: T) where T: FixedWidthInteger {
        let value = UInt64(seed)
        state = (value, value, value, value)
    }

    mutating func next() -> UInt64 {
        let x = state.1 &* 5
        let result = ((x &<< 7) | (x &>> 57)) &* 9
        let t = state.1 &<< 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = (state.3 &<< 45) | (state.3 &>> 19)
        return result
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private extension SwiftUI.Path {
    var ft_svgString: String {
        var d = ""
        forEach { element in
            switch element {
            case let .move(to):
                d += "M \(to.ft_svgString) "
            case let .line(to):
                d += "L \(to.ft_svgString) "
            case let .quadCurve(to, control):
                d += "Q \(control.ft_svgString) \(to.ft_svgString) "
            case let .curve(to, control1, control2):
                d += "C \(control1.ft_svgString) \(control2.ft_svgString) \(to.ft_svgString) "
            case .closeSubpath:
                d += "Z "
            }
        }
        return d.trimmingCharacters(in: .whitespaces)
    }
}

private extension CGPoint {
    var ft_svgString: String {
        "\(x.ft_svgString) \(y.ft_svgString)"
    }
}

private extension CGFloat {
    var ft_svgString: String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), self)
    }
}

private extension CGImage {
    func ft_isLikelyBundled(scale: CGFloat) -> Bool {
        let maxDimension: CGFloat = 100
        return CGFloat(width) / scale <= maxDimension && CGFloat(height) / scale <= maxDimension
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private extension UIImage.Orientation {
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

@available(iOS 13.0, *)
private extension FTSwiftUIResourcePayload {
    static func imageResource(image: UIImage, tintColor: UIColor?) -> FTSwiftUIResourcePayload? {
        let renderedImage: UIImage
        if let tintColor {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            tintColor.setFill()
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)
            UIRectFillUsingBlendMode(rect, .sourceAtop)
            renderedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            renderedImage = image
        }
        guard let data = renderedImage.pngData() else {
            return nil
        }
        return FTSwiftUIResourcePayload(identifier: data.ft_md5String, mimeType: "image/png", data: data)
    }
}

private extension Data {
    var ft_md5String: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

private extension CGColor {
    var ft_hexString: String {
        let converted = converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ) ?? self
        guard let components = converted.components else {
            return "#00000000"
        }
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        if components.count >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else {
            red = components.first ?? 0
            green = red
            blue = red
        }
        let alpha = converted.alpha
        return String(
            format: "#%02X%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded()),
            Int((alpha * 255).rounded())
        )
    }
}

#endif
