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

/// A flag used in `MODSEQ` search operations.
///
/// Attribute flags represent message flags in the context of the `MODSEQ` conditional STORE extension
/// defined in [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162). They are similar to standard
/// ``Flag`` values but are specifically used for searching based on modification sequences.
///
/// **Note:** Unlike ``Flag``, attribute flags do not include the `\Recent` flag, as `\Recent` is not persistent.
///
/// Attribute flags are case-insensitive for comparison but preserve their original casing when transmitted.
/// They are normalized to lowercase for comparison.
///
/// ### Standard Attribute Flags
///
/// - ``answered`` - The message has been replied to.
/// - ``flagged`` - The message has been marked for attention.
/// - ``deleted`` - The message has been deleted.
/// - ``seen`` - The message has been read by the user.
/// - ``draft`` - The message is incomplete and has not been sent.
///
/// - SeeAlso: [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1)
/// - SeeAlso: ``Flag``
public struct AttributeFlag: Hashable, Sendable {
    /// The raw lowercase string representation of the flag.
    internal let stringValue: String

    /// The `\Answered` attribute flag - the message has been replied to.
    ///
    /// Corresponds to the `\Answered` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let answered = Self("\\\\Answered")

    /// The `\Flagged` attribute flag - the message has been marked for attention.
    ///
    /// Corresponds to the `\Flagged` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let flagged = Self("\\\\Flagged")

    /// The `\Deleted` attribute flag - the message has been deleted.
    ///
    /// Corresponds to the `\Deleted` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let deleted = Self("\\\\Deleted")

    /// The `\Seen` attribute flag - the message has been read by the user.
    ///
    /// Corresponds to the `\Seen` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let seen = Self("\\\\Seen")

    /// The `\Draft` attribute flag - the message is incomplete and has not been sent.
    ///
    /// Corresponds to the `\Draft` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let draft = Self("\\\\Draft")

    /// Creates a new attribute flag from a string.
    ///
    /// The provided string is automatically lowercased to normalize the flag value, allowing case-insensitive
    /// comparison while preserving the original casing for transmission.
    ///
    /// - parameter stringValue: The flag string (e.g., `"\\Answered"`, `"\\SEEN"`). Will be lowercased.
    public init(_ stringValue: String) {
        self.stringValue = stringValue.lowercased()
    }
}

extension String {
    /// Creates a `String` from an ``AttributeFlag``.
    ///
    /// - parameter other: The attribute flag to convert.
    public init(_ other: AttributeFlag) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAttributeFlag(_ flag: AttributeFlag) -> Int {
        self.writeString(flag.stringValue)
    }
}
