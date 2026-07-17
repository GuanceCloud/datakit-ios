//
//  ShapeResource.swift
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

import CommonCrypto
import Foundation

@available(iOS 13.0, *)
final class FTShapeResource: NSObject {
    let svgString: String
    let mimeType = "image/svg+xml"

    private lazy var identifier = makeIdentifier()
    private lazy var data = makeData()

    init(svgString: String) {
        self.svgString = svgString
    }

    func makePayload() -> FTSwiftUIResourcePayload {
        FTSwiftUIResourcePayload(identifier: identifier, mimeType: mimeType, data: data)
    }

    private func makeIdentifier() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private func makeData() -> Data {
        Data(svgString.utf8)
    }
}

#endif
