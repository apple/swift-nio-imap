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
    /// Extracted from IMAPv4 `body-ext-1part`
    public struct FieldLanguageLocation: Equatable {
        public var languages: [String]
        public var location: FieldLocationExtension?

        public init(languages: [String], location: BodyStructure.FieldLocationExtension? = nil) {
            self.languages = languages
            self.location = location
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFieldLanguageLocation(_ langLoc: BodyStructure.FieldLanguageLocation) -> Int {
        self.writeSpace() +
            self.writeBodyFieldLanguages(langLoc.languages) +
            self.writeIfExists(langLoc.location) { (location) -> Int in
                self.writeBodyFieldLocationExtension(location)
            }
    }
}
