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

/// Data sent from the server to signal a success or failure.
public struct ResponseText: Hashable, Sendable {
    /// Used as a quick way to signal, e.g. *[ALERT]*. Not required.
    public var code: ResponseTextCode?

    /// A human-readable description.
    public var text: String

    /// Creates a new `ResponseText`.
    /// - parameter code: Used as a quick way to signal, e.g. *[ALERT]*. Not required. Defaults to `nil`.
    /// - parameter text: A human-readable description.
    public init(code: ResponseTextCode? = nil, text: String) {
        self.code = code
        self.text = text
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseText(_ text: ResponseText) -> Int {
        self.writeIfExists(text.code) { (code) -> Int in
            self.writeString("[") +
                self.writeResponseTextCode(code) +
                self.writeString("] ")
        } +

            // If the text is empty, write an additional space
            // to enforce standard compliance. Oddly, this is
            // perfectly legal IMAP.
            self.writeText(text.text.count > 0 ? text.text : " ")
    }

    @discardableResult mutating func writeText(_ text: String) -> Int {
        self.writeString(text)
    }
}

extension ResponseText: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeResponseText(self)
        }
    }
}
