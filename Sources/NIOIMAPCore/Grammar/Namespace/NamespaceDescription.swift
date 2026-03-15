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
/// This type represents one namespace descriptor in the server's namespace configuration (RFC 2342).
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
/// This response contains two personal namespace descriptors:
/// - The first is ``NamespaceDescription`` with prefix `""` (empty string) and delimiter `/`
/// - The second is ``NamespaceDescription`` with prefix `INBOX.` and delimiter `.`
///
/// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342#section-6)
public struct NamespaceDescription: Hashable, Sendable {
    /// The namespace prefix string.
    ///
    /// This prefix specifies the root of the namespace. Mailboxes within this namespace
    /// are accessed by appending the mailbox name to this prefix, separated by the delimiter.
    /// An empty string indicates the namespace has no prefix (mailboxes are accessed directly).
    public var string: ByteBuffer

    /// The hierarchy delimiter for this namespace, or `nil` if no delimiter is used.
    ///
    /// The delimiter separates components of a mailbox name in this namespace. Common delimiters
    /// include `/` and `.`. If `nil`, the namespace does not use a hierarchy delimiter,
    /// meaning mailbox names are not hierarchical within this namespace.
    public var delimiter: Character?

    /// Response extensions for this namespace, supporting future protocol enhancements.
    ///
    /// This dictionary contains arbitrary key-value pairs that may be included by servers
    /// to provide additional namespace information. Keys are extension names, and values are
    /// arrays of strings containing the extension parameters.
    /// Non-standard extensions should be prefixed with `X-` as per RFC 2342.
    public var responseExtensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>

    /// Creates a new `NamespaceDescription`.
    ///
    /// - Parameters:
    ///   - string: The namespace prefix string.
    ///   - char: The hierarchy delimiter for this namespace, or `nil` if not used.
    ///   - responseExtensions: Response extensions for this namespace.
    public init(
        string: ByteBuffer,
        char: Character? = nil,
        responseExtensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>
    ) {
        self.string = string
        self.delimiter = char
        self.responseExtensions = responseExtensions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceDescription(_ description: NamespaceDescription) -> Int {
        var size = 0
        size += self.writeString("(")
        size += self.writeIMAPString(description.string)
        size += self.writeSpace()

        if let char = description.delimiter {
            size += self.writeString("\"\(char)\"")
        } else {
            size += self.writeNil()
        }

        size += self.writeNamespaceResponseExtensions(description.responseExtensions)
        size += self.writeString(")")
        return size
    }
}
