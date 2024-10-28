//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// https://github.com/swift-extras/swift-extras-base64

// minor modifications to remove public attributes

@usableFromInline
enum Base64 {
    @usableFromInline
    struct EncodingOptions: OptionSet, Sendable {
        @usableFromInline
        let rawValue: UInt

        @usableFromInline
        init(rawValue: UInt) { self.rawValue = rawValue }

        @usableFromInline
        static let base64UrlAlphabet = EncodingOptions(rawValue: UInt(1 << 0))

        @usableFromInline
        static let omitPaddingCharacter = EncodingOptions(rawValue: UInt(1 << 1))
    }

    @usableFromInline
    struct DecodingOptions: OptionSet, Sendable {
        @usableFromInline
        let rawValue: UInt

        @usableFromInline
        init(rawValue: UInt) { self.rawValue = rawValue }

        @usableFromInline
        static let base64UrlAlphabet = DecodingOptions(rawValue: UInt(1 << 0))

        @usableFromInline
        static let omitPaddingCharacter = DecodingOptions(rawValue: UInt(1 << 1))
    }
}

//// MARK: - Extensions -

extension String {
    @usableFromInline
    init<Buffer: Collection>(base64Encoding bytes: Buffer, options: Base64.EncodingOptions = [])
    where Buffer.Element == UInt8 {
        self = Base64.encodeString(bytes: bytes, options: options)
    }

    func base64decoded(options: Base64.DecodingOptions = []) throws -> [UInt8] {
        try Base64.decode(string: self, options: options)
    }
}
