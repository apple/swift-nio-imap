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
import struct OrderedCollections.OrderedDictionary

/// A description of a single namespace, including its prefix and hierarchy delimiter.
///
/// Represents one namespace descriptor in the server's namespace configuration (RFC 2342).
/// It consists of a prefix string that specifies the mailbox path hierarchy and an optional hierarchy
/// delimiter that separates mailbox name components. For namespaces that do not use a hierarchy delimiter,
/// the delimiter is `nil`.
///
/// Response extensions may be included with each namespace to support future protocol enhancements.
///
/// ### Example
///
/// ```
/// S: * NAMESPACE (("" "/") ("INBOX." ".")) NIL NIL
/// ```
///
/// The response contains two personal namespace descriptors:
/// - The first is ``NamespaceDescription`` with prefix `""` (empty string) and delimiter `/`
/// - The second is ``NamespaceDescription`` with prefix `INBOX.` and delimiter `.`
///
/// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342#section-6)
public struct NamespaceDescription: Hashable, Sendable {
    /// The namespace prefix string.
    ///
    /// Specifies the root of the namespace. Mailboxes within this namespace
    /// are accessed by appending the mailbox name to this prefix, separated by the delimiter.
    /// An empty string indicates the namespace has no prefix (mailboxes are accessed directly).
    public var string: ByteBuffer

    /// The hierarchy delimiter for this namespace, or `nil` if no delimiter is used.
    ///
    /// The delimiter separates components of a mailbox name in this namespace. Common delimiters
    /// include `/` and `.`. If `nil`, the namespace does not use a hierarchy delimiter,
    /// meaning mailbox names are not hierarchical within this namespace.
    public var delimiter: Character? {
        self.delimiterByte.map { Character(Unicode.Scalar($0)) }
    }

    /// A `QUOTED-CHAR` (unescaped), or `nil`.
    let delimiterByte: UInt8?

    /// Response extensions for this namespace, supporting future protocol enhancements.
    ///
    /// Contains arbitrary key-value pairs that may be included by servers
    /// to provide additional namespace information. Keys are extension names, and values are
    /// arrays of strings containing the extension parameters.
    /// Non-standard extensions should be prefixed with `X-` as per RFC 2342.
    public var responseExtensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>

    /// Creates a new `NamespaceDescription`.
    ///
    /// - Parameters:
    ///   - string: The namespace prefix string.
    ///   - delimiter: The hierarchy delimiter for this namespace, or `nil` if not used.
    ///   - responseExtensions: Response extensions for this namespace.
    /// - Throws: ``InvalidDelimiterError`` if `delimiter` is not an ASCII character, or is CR, LF, or
    ///   NUL (which can't be written as a `QUOTED-CHAR`).
    public init(
        string: ByteBuffer,
        delimiter: Character? = nil,
        responseExtensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>
    ) throws {
        var delimiterByte: UInt8?
        if let delimiter {
            // `Character("\r\n").asciiValue` is LF, so CRLF is rejected too.
            guard let byte = delimiter.asciiValue, Self.isValidDelimiter(byte) else {
                throw InvalidDelimiterError(delimiter: delimiter)
            }
            delimiterByte = byte
        }
        self.init(string: string, delimiterByte: delimiterByte, responseExtensions: responseExtensions)
    }

    init(
        string: ByteBuffer,
        delimiterByte: UInt8?,
        responseExtensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>
    ) {
        assert(delimiterByte.map(Self.isValidDelimiter) ?? true)
        self.string = string
        self.delimiterByte = delimiterByte
        self.responseExtensions = responseExtensions
    }

    /// Whether the given byte can be written as a `QUOTED-CHAR`
    /// ([RFC 2342 Section 6](https://datatracker.ietf.org/doc/html/rfc2342#section-6)), escaping
    /// quoted-specials:
    /// ```
    /// QUOTED-CHAR = <any TEXT-CHAR except quoted-specials> / "\" quoted-specials
    /// ```
    static func isValidDelimiter(_ byte: UInt8) -> Bool {
        byte.isTextChar
    }
}

extension NamespaceDescription {
    /// The error thrown when a namespace delimiter can't be written as a `QUOTED-CHAR`.
    public struct InvalidDelimiterError: Error, Hashable {
        /// The rejected delimiter.
        public var delimiter: Character
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceDescription(_ description: NamespaceDescription) -> Int {
        var size = 0
        size += self.writeString("(")
        size += self.writeIMAPString(description.string)
        size += self.writeSpace()

        if let byte = description.delimiterByte {
            // DQUOTE QUOTED-CHAR DQUOTE, QUOTED-CHAR = ... / "\" quoted-specials
            size += self.writeString("\"")
            if byte.isQuotedSpecial {
                size += self.writeString("\\")
            }
            size += self.writeString(String(UnicodeScalar(byte)))
            size += self.writeString("\"")
        } else {
            size += self.writeNil()
        }

        size += self.writeNamespaceResponseExtensions(description.responseExtensions)
        size += self.writeString(")")
        return size
    }
}
