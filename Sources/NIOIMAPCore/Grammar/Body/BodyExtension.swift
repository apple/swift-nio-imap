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

/// A generic extension field for future `BODY` structure enhancements (RFC 3501).
///
/// RFC 3501 allows servers to include extension fields after the standard body structure fields
/// to support future IMAP extensions. This enum captures those extension fields as either
/// string (nstring) or numeric values, providing forward compatibility without requiring
/// library updates.
///
/// When a server includes extension data in a `BODY` or `BODYSTRUCTURE` response, each
/// extension field is represented as either a ``string(_:)`` or ``number(_:)`` case.
///
/// ### Example
///
/// A future RFC might extend `BODY` responses to include a custom numeric field or string field.
/// When received, these would be represented as ``BodyExtension`` values in the extension arrays.
///
/// - SeeAlso: [RFC 3501 Section 2.6.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.6.3)
/// - SeeAlso: ``Singlepart/Extension``
/// - SeeAlso: ``Multipart/Extension``
public enum BodyExtension: Hashable, Sendable {
    /// A generic string extension field, or `nil` if not present.
    ///
    /// Represents an optional string value in an extension field, following IMAP's nstring syntax.
    case string(ByteBuffer?)

    /// A generic numeric extension field.
    ///
    /// Represents an integer value in an extension field.
    case number(Int)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyExtensions(_ ext: [BodyExtension]) -> Int {
        self.writeArray(ext) { (element, self) in
            self.writeBodyExtension(element)
        }
    }

    @discardableResult mutating func writeBodyExtension(_ type: BodyExtension) -> Int {
        switch type {
        case .string(let string):
            return self.writeNString(string)
        case .number(let number):
            return self.writeString("\(number)")
        }
    }
}
