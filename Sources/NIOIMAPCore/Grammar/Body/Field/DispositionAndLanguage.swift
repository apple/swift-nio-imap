//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

extension BodyStructure {
    /// Extracted from IMAPv4 `body-ext-`1part
    public struct DispositionAndLanguage: Equatable {
        /// A parenthesized list, consisting of a disposition type
        /// string, followed by a parenthesized list of disposition
        /// attribute/value pairs as defined in RFC 2183.
        public var disposition: Disposition?
        public var language: LanguageLocation?

        public init(disposition: Disposition? = nil, language: LanguageLocation? = nil) {
            self.disposition = disposition
            self.language = language
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyDispositionAndLanguage(_ desc: BodyStructure.DispositionAndLanguage) -> Int {
        self.writeSpace() +
            self.writeBodyFieldDisposition(desc.disposition)
    }
}
