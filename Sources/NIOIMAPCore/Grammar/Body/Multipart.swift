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
    /// A multipart MIME message body as defined in RFC 3501.
    ///
    /// A multipart body represents a message divided into multiple MIME parts. Common multipart types include:
    /// - `multipart/mixed`: Parts with different media types mixed together
    /// - `multipart/alternative`: Alternative representations of the same content (e.g., plain text and HTML)
    /// - `multipart/related`: Parts that reference each other (e.g., HTML with embedded images)
    ///
    /// Each part in a multipart body is itself a ``BodyStructure``, which may be another multipart, creating
    /// arbitrarily deep nesting. Optional extension fields provide forward compatibility with future extensions.
    ///
    /// ### Example
    ///
    /// ```
    /// (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 1234 20) ("text" "html" ("charset" "us-ascii") NIL NIL "7bit" 5678 45) "alternative")
    /// ```
    ///
    /// This is parsed as a ``Multipart`` with two parts (text/plain and text/html) and media subtype `alternative`.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    /// - SeeAlso: [RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045)
    public struct Multipart: Hashable, Sendable {
        /// The MIME parts contained in this multipart body.
        ///
        /// Each part is indexed starting from 1 (not 0), following IMAP conventions.
        /// Parts may be accessed using ``SectionSpecifier/Part`` indices.
        public var parts: [BodyStructure]

        /// The multipart subtype (e.g., `mixed` for `multipart/mixed`, `alternative` for `multipart/alternative`).
        ///
        /// The subtype indicates how the parts should be interpreted or presented.
        public var mediaSubtype: Media.Subtype

        /// Optional extension fields for future IMAP extensions.
        ///
        /// Per RFC 3501, servers may include extension data after the standard fields for forward compatibility.
        /// These fields are optional and not required to construct a valid multipart body.
        public var `extension`: Extension?

        /// Creates a new multipart body.
        /// - parameter parts: The MIME parts that comprise this multipart
        /// - parameter mediaSubtype: The multipart subtype (e.g., `mixed`, `alternative`)
        /// - parameter extension: Optional extension fields (defaults to `nil`)
        public init(parts: [BodyStructure], mediaSubtype: Media.Subtype, extension: Extension? = nil) {
            self.parts = parts
            self.mediaSubtype = mediaSubtype
            self.extension = `extension`
        }
    }
}

extension BodyStructure.Multipart {
    /// Optional extension fields for multipart bodies (RFC 3501).
    ///
    /// RFC 3501 allows servers to include extension data after the standard multipart fields
    /// (parameters and optional disposition/language information) to support future extensions
    /// without breaking existing clients.
    public struct Extension: Hashable, Sendable {
        /// MIME parameters for the multipart structure itself (e.g., `boundary` parameter).
        ///
        /// Contains key/value pairs as an ordered dictionary, preserving the server's order.
        public var parameters: OrderedDictionary<String, String>

        /// Optional disposition information and language metadata.
        ///
        /// When present, describes how the multipart should be displayed and what languages are used.
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Creates a new multipart extension.
        /// - parameter parameters: MIME parameters for the multipart structure
        /// - parameter dispositionAndLanguage: Optional disposition and language metadata
        public init(
            parameters: OrderedDictionary<String, String>,
            dispositionAndLanguage: BodyStructure.DispositionAndLanguage?
        ) {
            self.parameters = parameters
            self.dispositionAndLanguage = dispositionAndLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyMultipart(_ part: BodyStructure.Multipart) -> Int {
        part.parts.reduce(into: 0) { (result, body) in
            result += self.writeBody(body)
        } + self.writeSpace() + self.writeMediaSubtype(part.mediaSubtype)
            + self.writeIfExists(part.extension) { (ext) -> Int in
                self.writeSpace() + self.writeBodyExtensionMultipart(ext)
            }
    }

    @discardableResult mutating func writeBodyExtensionMultipart(_ ext: BodyStructure.Multipart.Extension) -> Int {
        self.writeBodyParameterPairs(ext.parameters)
            + self.writeIfExists(ext.dispositionAndLanguage) { (dspLanguage) -> Int in
                self.writeBodyDispositionAndLanguage(dspLanguage)
            }
    }
}
