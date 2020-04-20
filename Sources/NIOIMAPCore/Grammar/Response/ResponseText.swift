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

extension NIOIMAP {

    /// IMAPv4 `resp-text`
    public struct ResponseText: Equatable {
        public var code: ResponseTextCode?
        public var text: ByteBuffer

        /// Convenience function for a better experience when chaining multiple types.
        public static func code(_ code: ResponseTextCode?, text: ByteBuffer) -> Self {
            return Self(code: code, text: text)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeResponseText(_ text: NIOIMAP.ResponseText) -> Int {
        self.writeIfExists(text.code) { (code) -> Int in
            self.writeString("[") +
            self.writeResponseTextCode(code) +
            self.writeString("] ")
        } +
        self.writeText(text.text)
    }
    
    @discardableResult mutating func writeText(_ text: ByteBuffer) -> Int {
        var copy = text
        return self.writeBuffer(&copy)
    }

}
