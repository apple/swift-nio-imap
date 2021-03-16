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
    /// Pairs a body `Disposition` with a `LanguageLocation`. An abstraction from RFC 3501
    /// to make the API slightly easier to work with and enforce validity.
    public struct DispositionAndLanguage: Equatable {
        /// Some body `Disposition`
        public var disposition: Disposition?

        /// Some *Language/Location* pair
        public var language: LanguageLocation?

        /// Creates a new `DispositionAndLanguage`.
        /// - parameter disposition: The disposition to pair.
        /// - parameter language: Some *Language/Location* pair, defaults to `nil`.
        public init(disposition: Disposition?, language: LanguageLocation? = nil) {
            self.disposition = disposition
            self.language = language
        }
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeBodyDispositionAndLanguage(_ desc: BodyStructure.DispositionAndLanguage) -> Int {
        self.writeSpace() +
            self.writeBodyDisposition(desc.disposition)
    }
}
