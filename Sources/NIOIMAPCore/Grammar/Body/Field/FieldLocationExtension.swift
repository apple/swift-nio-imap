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
    public struct FieldLocationExtension: Equatable {
        public var location: NString
        public var extensions: [[BodyExtensionType]]

        public static func location(_ location: NString, extensions: [[BodyExtensionType]]) -> Self {
            Self(location: location, extensions: extensions)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFieldLocationExtension(_ locationExtension: BodyStructure.FieldLocationExtension) -> Int {
        self.writeSpace() +
            self.writeNString(locationExtension.location) +
            locationExtension.extensions.reduce(0) { (result, ext) in
                result +
                    self.writeSpace() +
                    self.writeBodyExtension(ext)
            }
    }
}
