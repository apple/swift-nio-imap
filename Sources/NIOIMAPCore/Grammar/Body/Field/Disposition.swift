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

extension BodyStructure {
    /// The type of content disposition for a message part.
    ///
    /// The disposition kind specifies how a message part should be displayed to the user, either `inline`
    /// as part of the message body or as an `attachment` to be downloaded separately. The value is
    /// case-insensitive and normalized to lowercase for comparison.
    ///
    /// - SeeAlso: [RFC 2183 Section 2](https://datatracker.ietf.org/doc/html/rfc2183#section-2)
    public struct DispositionKind: Hashable, RawRepresentable, Sendable {
        /// The `inline` disposition, indicating the part should be displayed as part of the message body.
        ///
        /// This is the default disposition when not specified. Inline parts are typically displayed automatically
        /// by mail clients as part of the message preview.
        public static let inline = Self(rawValue: "inline")

        /// The `attachment` disposition, indicating the part should be treated as a downloadable attachment.
        ///
        /// Attachment parts are typically not displayed automatically but are made available for download by the mail client.
        public static let attachment = Self(rawValue: "attachment")

        /// The disposition kind as a lowercase string.
        public let rawValue: String

        /// Creates a disposition kind from a string.
        ///
        /// The provided string is automatically lowercased to normalize the disposition value, allowing
        /// case-insensitive comparison.
        ///
        /// - parameter rawValue: The disposition kind (e.g., `"inline"`, `"attachment"`). Will be lowercased.
        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }
    }

    /// The content disposition parameters of a message part.
    ///
    /// The disposition describes how a message part should be handled by the recipient, including its
    /// type (`inline` or `attachment`) and optional parameters such as filename. These parameters provide
    /// additional information for handling the part, defined in [RFC 2183](https://datatracker.ietf.org/doc/html/rfc2183)
    /// and included in message body structures via [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2).
    ///
    /// The `parameters` dictionary is an ordered collection allowing multiple values for the same parameter name
    /// as they appear in the message, though typically only the first value is used.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE (("text" "plain" NIL NIL NIL "7bit" 512 10 NIL ("inline" NIL)) ("text" "html" NIL NIL NIL "7bit" 1024 20 NIL ("attachment" (("filename" "document.html"))))))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The disposition `("inline" NIL)` corresponds to a ``Disposition`` with ``kind`` = ``DispositionKind/inline``
    /// and no parameters. The disposition `("attachment" (("filename" "document.html")))` has ``kind`` = ``DispositionKind/attachment``
    /// and a `filename` parameter with value `"document.html"`.
    ///
    /// - SeeAlso: [RFC 2183](https://datatracker.ietf.org/doc/html/rfc2183)
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    public struct Disposition: Hashable, Sendable {
        /// The disposition kind (e.g., `inline` or `attachment`).
        public var kind: DispositionKind

        /// Optional parameters associated with the disposition.
        ///
        /// Common parameters include `filename` (the recommended filename for saving the part) and `size`
        /// (the size in bytes). Parameters are stored in an ordered dictionary, preserving the order they appear in the message.
        public var parameters: OrderedDictionary<String, String>

        /// Creates a new disposition.
        ///
        /// - parameter kind: The disposition kind (`inline` or `attachment`).
        /// - parameter parameters: An ordered dictionary of disposition parameters (e.g., filename, size).
        public init(kind: DispositionKind, parameters: OrderedDictionary<String, String>) {
            self.kind = kind
            self.parameters = parameters
        }

        /// The `size` parameter value, if present and valid.
        ///
        /// The `size` parameter indicates the size in bytes of the message part. If the parameter is not present
        /// or cannot be parsed as an integer, this returns `nil`.
        ///
        /// - Returns: The size value as an integer, or `nil` if not present or invalid.
        public var size: Int? {
            guard
                let value = self.parameters.first(where: { (pair) -> Bool in
                    pair.0.lowercased() == "size"
                })?.1
            else {
                return nil
            }
            return Int(value)
        }

        /// The `filename` parameter value, if present.
        ///
        /// The `filename` parameter provides a recommended filename for saving the message part to disk.
        /// This is commonly used for attachment parts.
        ///
        /// - Returns: The filename string, or `nil` if the parameter is not present.
        public var filename: String? {
            self.parameters.first(where: { (pair) -> Bool in
                pair.0.lowercased() == "filename"
            })?.1
        }
    }
}

extension BodyStructure.DispositionKind: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value.lowercased()
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyDisposition(_ dsp: BodyStructure.Disposition?) -> Int {
        guard let dsp = dsp else {
            return self.writeNil()
        }

        return
            self.writeString("(") + self.writeIMAPString(dsp.kind.rawValue) + self.writeSpace()
            + self.writeBodyParameterPairs(dsp.parameters) + self.writeString(")")
    }
}
