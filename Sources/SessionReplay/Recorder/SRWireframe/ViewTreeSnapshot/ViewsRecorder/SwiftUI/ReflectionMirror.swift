//
//  ReflectionMirror.swift
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
import SwiftShims

struct FTReflectionMirror {
    typealias Child = (label: String?, value: Any)
    typealias Children = AnyCollection<Child>

    enum DisplayStyle: Equatable {
        case `struct`
        case `class`
        case `enum`(String)
        case tuple
        case `nil`
        case opaque
    }

    enum Path {
        case index(Int)
        case key(String)

        var label: String {
            switch self {
            case let .index(index):
                return String(index)
            case let .key(key):
                return key
            }
        }
    }

    private final class LazyBox<T> {
        lazy var value: T = load()
        private let load: () -> T

        init(_ load: @escaping () -> T) {
            self.load = load
        }
    }

    let subject: Any
    let subjectType: Any.Type
    let displayStyle: DisplayStyle
    let children: Children

    var superclassMirror: FTReflectionMirror? {
        superclassMirrorBox.value
    }

    var keyPaths: [String: Int]? {
        keyPathsBox.value
    }

    private let superclassMirrorBox: LazyBox<FTReflectionMirror?>
    private let keyPathsBox: LazyBox<[String: Int]?>

    init<C>(
        subject: Any,
        subjectType: Any.Type,
        displayStyle: DisplayStyle,
        children: C = [],
        keyPaths: @autoclosure @escaping () -> [String: Int]? = nil,
        superclassMirror: @autoclosure @escaping () -> FTReflectionMirror? = nil
    ) where C: Collection, C.Element == Child {
        self.subject = subject
        self.subjectType = subjectType
        self.displayStyle = displayStyle
        self.children = Children(children)
        self.keyPathsBox = LazyBox(keyPaths)
        self.superclassMirrorBox = LazyBox(superclassMirror)
    }

    init(reflecting subject: Any, subjectType: Any.Type? = nil) {
        let subjectType = subjectType ?? ft_getNormalizedType(subject, type: Swift.type(of: subject))
        let metadataKind = FTMetadataKind(subjectType)

        switch metadataKind {
        case .class, .foreignClass, .objcClassWrapper:
            let childCount = ft_getChildCount(subject, type: subjectType)
            self.init(
                subject: subject,
                subjectType: subjectType,
                displayStyle: .class,
                children: Self.children(of: subject, type: subjectType, count: childCount),
                keyPaths: Self.keyPaths(
                    subjectType,
                    count: childCount,
                    recursiveCount: ft_getRecursiveChildCount(subjectType)
                ),
                superclassMirror: _getSuperclass(subjectType).map {
                    FTReflectionMirror(reflecting: subject, subjectType: $0)
                }
            )

        case .struct:
            let childCount = ft_getChildCount(subject, type: subjectType)
            self.init(
                subject: subject,
                subjectType: subjectType,
                displayStyle: .struct,
                children: Self.children(of: subject, type: subjectType, count: childCount),
                keyPaths: Self.keyPaths(subjectType, count: childCount)
            )

        case .enum:
            let childCount = ft_getChildCount(subject, type: subjectType)
            let caseName = ft_getEnumCaseName(subject).map { String(cString: $0) } ?? ""
            self.init(
                subject: subject,
                subjectType: subjectType,
                displayStyle: .enum(caseName),
                children: Self.children(of: subject, type: subjectType, count: childCount)
            )

        case .tuple:
            let childCount = ft_getChildCount(subject, type: subjectType)
            self.init(
                subject: subject,
                subjectType: subjectType,
                displayStyle: .tuple,
                children: Self.children(of: subject, type: subjectType, count: childCount)
            )

        case .optional:
            if ft_getChildCount(subject, type: subjectType) > 0 {
                let some = Self.child(of: subject, type: subjectType, index: 0)
                self.init(reflecting: some.value)
            } else {
                self.init(subject: subject, subjectType: subjectType, displayStyle: .nil)
            }

        default:
            self.init(subject: subject, subjectType: subjectType, displayStyle: .opaque)
        }
    }

    func descendant(_ first: Path, _ rest: Path...) -> Any? {
        var paths = [first] + rest
        return descendant(paths: &paths)
    }

    func descendant(_ paths: [Path]) -> Any? {
        var paths = paths
        return descendant(paths: &paths)
    }

    private func descendant(paths: inout [Path]) -> Any? {
        let path = paths.removeFirst()

        guard let child = descendant(path) else {
            return nil
        }

        if paths.isEmpty {
            return child
        }

        return FTReflectionMirror(reflecting: child)
            .descendant(paths: &paths)
    }

    private func descendant(_ path: Path) -> Any? {
        if case let .index(index) = path, index >= 0 {
            let childIndex = children.index(children.startIndex, offsetBy: index, limitedBy: children.endIndex)
            if let childIndex, childIndex != children.endIndex {
                return children[childIndex].value
            }
        }

        if case let .key(key) = path, let index = keyPaths?[key] {
            let childIndex = children.index(children.startIndex, offsetBy: index, limitedBy: children.endIndex)
            if let childIndex, childIndex != children.endIndex {
                return children[childIndex].value
            }
        }

        return superclassMirror?.descendant(path)
    }

    private static func child<T>(of value: T, type: Any.Type, index: Int) -> Child {
        var nameC: UnsafePointer<CChar>?
        var freeFunc: FTNameFreeFunc?
        let value = ft_getChild(of: value, type: type, index: index, outName: &nameC, outFreeFunc: &freeFunc)
        let name = nameC.flatMap { String(cString: $0) }
        freeFunc?(nameC)
        return (name, value)
    }

    private static func children<T>(of value: T, type: Any.Type, count: Int) -> Children {
        Children((0 ..< count).lazy.map {
            child(of: value, type: type, index: $0)
        })
    }

    private static func keyPaths(_ type: Any.Type, count: Int) -> [String: Int] {
        keyPaths(type, count: count, recursiveCount: count)
    }

    private static func keyPaths(_ type: Any.Type, count: Int, recursiveCount: Int) -> [String: Int] {
        let skip = recursiveCount - count
        return (skip ..< recursiveCount).reduce(into: [:]) { result, index in
            var field = _FieldReflectionMetadata()
            _ = ft_getChildMetadata(type, index: index, fieldMetadata: &field)
            field.name
                .flatMap { String(cString: $0) }
                .map { result[$0] = index - skip }
            field.freeFunc?(field.name)
        }
    }
}

extension FTReflectionMirror.Path: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .index(value)
    }
}

extension FTReflectionMirror.Path: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .key(value)
    }
}

@_silgen_name("swift_EnumCaseName")
private func ft_getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

@_silgen_name("swift_getMetadataKind")
private func ft_metadataKind(_: Any.Type) -> UInt

@_silgen_name("swift_reflectionMirror_normalizedType")
private func ft_getNormalizedType<T>(_: T, type: Any.Type) -> Any.Type

@_silgen_name("swift_reflectionMirror_count")
private func ft_getChildCount<T>(_: T, type: Any.Type) -> Int

@_silgen_name("swift_reflectionMirror_recursiveCount")
private func ft_getRecursiveChildCount(_: Any.Type) -> Int

@_silgen_name("swift_reflectionMirror_recursiveChildMetadata")
private func ft_getChildMetadata(
    _: Any.Type,
    index: Int,
    fieldMetadata: UnsafeMutablePointer<_FieldReflectionMetadata>
) -> Any.Type

private typealias FTNameFreeFunc = @convention(c) (UnsafePointer<CChar>?) -> Void

@_silgen_name("swift_reflectionMirror_subscript")
private func ft_getChild<T>(
    of: T,
    type: Any.Type,
    index: Int,
    outName: UnsafeMutablePointer<UnsafePointer<CChar>?>,
    outFreeFunc: UnsafeMutablePointer<FTNameFreeFunc?>
) -> Any

private enum FTMetadataKind: UInt {
    case `class` = 0
    case `struct` = 0x200
    case `enum` = 0x201
    case optional = 0x202
    case foreignClass = 0x203
    case foreignReferenceType = 0x204
    case opaque = 0x300
    case tuple = 0x301
    case function = 0x302
    case existential = 0x303
    case metatype = 0x304
    case objcClassWrapper = 0x305
    case existentialMetatype = 0x306
    case extendedExistential = 0x307
    case heapLocalVariable = 0x400
    case heapGenericLocalVariable = 0x500
    case errorObject = 0x501
    case task = 0x502
    case job = 0x503
    case unknown = 0x7FF

    init(_ type: Any.Type) {
        self = FTMetadataKind(rawValue: ft_metadataKind(type)) ?? .unknown
    }
}

#endif
