//
//  FTSwiftUIReflection.swift
//  SessionReplay
//
//  Created by hulilei on 2026/4/29.
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
import QuartzCore
import SwiftUI
import UIKit

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

    init(builder: FTSwiftUIWireframesBuilder) {
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
    @objc let resourceData: Data?
    @objc let image: UIImage?
    @objc let tintColor: UIColor?

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
        mimeType: String? = nil,
        resourceData: Data? = nil,
        image: UIImage? = nil,
        tintColor: UIColor? = nil
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
        self.resourceData = resourceData
        self.image = image
        self.tintColor = tintColor
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
    @objc dynamic var backgroundColor: CGColor?
    @objc dynamic var borderColor: CGColor?
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
            let reflector = FTReflector(subject: rendererObject)
            return try FTSwiftUIRenderer(renderer: FTDisplayList.ViewRenderer(from: reflector).renderer)
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

#endif
