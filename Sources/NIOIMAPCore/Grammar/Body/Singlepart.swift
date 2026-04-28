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
    /// A single-part MIME message body as defined in RFC 3501.
    ///
    /// A single-part body represents a message containing only one MIME part. This includes simple
    /// media types (for example, `text/plain` or `image/jpeg`), the `message/rfc822` encapsulated message type,
    /// and text-specific types. Single-part bodies may have optional extension fields for forward compatibility.
    ///
    /// ### Example
    ///
    /// ```
    /// ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 3445 65)
    /// ```
    ///
    /// The wire format above is parsed as a ``Singlepart`` with `kind: .text(...)`, `fields: Fields(...)`, and no extension.
    ///
    /// - SeeAlso: [RFC 3501 Section 2.6.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.6.3)
    /// - SeeAlso: ``Kind``
    /// - SeeAlso: ``BodyStructure``
    public struct Singlepart: Hashable, Sendable {
        /// The type of this single-part body (basic media, message/rfc822, or text).
        public var kind: Kind

        /// Common fields present in all body structures (media parameters, content ID, description, encoding, size).
        public var fields: Fields

        /// Optional extension fields for future IMAP extensions.
        ///
        /// Per RFC 3501, servers may include extension data after the standard fields for forward compatibility.
        /// These fields are optional and not required to construct a valid single-part body.
        public var `extension`: Extension?

        /// Creates a new single-part body.
        /// - parameter kind: The type of single-part body
        /// - parameter fields: Common body fields
        /// - parameter extension: Optional extension fields (defaults to `nil`)
        public init(kind: BodyStructure.Singlepart.Kind, fields: Fields, extension: Extension? = nil) {
            self.kind = kind
            self.fields = fields
            self.extension = `extension`
        }
    }
}

// MARK: - Types

extension BodyStructure.Singlepart {
    /// The media type category of a single-part body (RFC 3501).
    ///
    /// Represents the three main kinds of single-part bodies: basic media types, encapsulated messages,
    /// and text-specific types. Each kind may have additional properties specific to that type.
    public indirect enum Kind: Hashable, Sendable {
        /// A simple, non-message media type (for example, `image/jpeg` or `application/pdf`).
        ///
        /// The associated ``Media/MediaType`` specifies the exact MIME type and subtype.
        case basic(Media.MediaType)

        /// An encapsulated RFC 822 email message (for example, `message/rfc822`).
        ///
        /// The associated ``Message`` contains the envelope and nested body of the embedded message.
        case message(Message)

        /// A text-specific body type with optional line count information.
        ///
        /// The associated ``Text`` specifies the text subtype (for example, `plain` or `html`).
        case text(Text)
    }

    /// A `message/rfc822` encapsulated email message with headers and body (RFC 3501).
    ///
    /// When a message contains another message as a body part, this structure describes
    /// the embedded message's envelope and body structure.
    public struct Message: Hashable, Sendable {
        /// The MIME subtype, typically `rfc822` for standard email messages.
        public var message: Media.Subtype

        /// The parsed headers of the embedded message, including sender, recipients, subject, and date.
        public var envelope: Envelope

        /// The hierarchical body structure of the embedded message.
        ///
        /// May itself be multipart, creating arbitrarily deep nesting of messages.
        public var body: BodyStructure

        /// The number of lines in the message (per RFC 2045/RFC 3501).
        public var lineCount: Int

        /// Creates a new encapsulated message.
        /// - parameter message: The MIME subtype (usually `rfc822`)
        /// - parameter envelope: The envelope structure of the embedded message
        /// - parameter body: The body structure of the embedded message
        /// - parameter lineCount: The line count of the embedded message
        public init(message: Media.Subtype, envelope: Envelope, body: BodyStructure, lineCount: Int) {
            self.message = message
            self.envelope = envelope
            self.body = body
            self.lineCount = lineCount
        }
    }

    /// A text-specific body part with MIME type `text/*` (RFC 3501).
    ///
    /// Text bodies are specialized single-part bodies with a specific subtype (for example, `plain` or `html`)
    /// and an associated line count.
    public struct Text: Hashable, Sendable {
        /// The text subtype (for example, `plain` for `text/plain` or `html` for `text/html`).
        public var mediaSubtype: Media.Subtype

        /// The number of lines in the text body (per RFC 2045/RFC 3501).
        ///
        /// Line count includes all lines in the text, including blank lines and lines of any length.
        public var lineCount: Int

        /// Creates a new text body.
        /// - parameter mediaSubtype: The text subtype (for example, `plain` or `html`)
        /// - parameter lineCount: The number of lines in the text
        public init(mediaSubtype: Media.Subtype, lineCount: Int) {
            self.mediaSubtype = mediaSubtype
            self.lineCount = lineCount
        }
    }

    /// Optional extension fields for single-part bodies, including MD5 digest and language information.
    ///
    /// Per RFC 3501, servers may include extension data after the standard fields. Currently defined
    /// extensions include optional body MD5 hash and disposition/language information. Future extensions
    /// may add additional fields.
    public struct Extension: Hashable, Sendable {
        /// The body MD5 digest value, if present.
        ///
        /// An optional MD5 hash of the body content (per RFC 2045), used to verify message integrity.
        public let digest: String?

        /// Optional disposition and language metadata.
        ///
        /// When present, describes how the body should be displayed and what languages are used.
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Creates a new extension.
        /// - parameter digest: The body MD5 digest value
        /// - parameter dispositionAndLanguage: Optional disposition and language metadata
        public init(digest: String?, dispositionAndLanguage: BodyStructure.DispositionAndLanguage?) {
            self.digest = digest
            self.dispositionAndLanguage = dispositionAndLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodySinglepart(_ part: BodyStructure.Singlepart) -> Int {
        var size = 0
        switch part.kind {
        case .basic(let basic):
            size += self.writeBodyKindBasic(mediaType: basic, fields: part.fields)
        case .message(let message):
            size += self.writeBodyKindMessage(message, fields: part.fields)
        case .text(let text):
            size += self.writeBodyKindText(text, fields: part.fields)
        }

        if let ext = part.extension {
            size += self.writeSpace()
            size += self.writeBodyExtensionSinglePart(ext)
        }
        return size
    }

    @discardableResult private mutating func writeBodyKindText(
        _ body: BodyStructure.Singlepart.Text,
        fields: BodyStructure.Fields
    ) -> Int {
        self.writeString(#""TEXT" "#) + self.writeMediaSubtype(body.mediaSubtype) + self.writeSpace()
            + self.writeBodyFields(fields) + self.writeString(" \(body.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindMessage(
        _ message: BodyStructure.Singlepart.Message,
        fields: BodyStructure.Fields
    ) -> Int {
        self.writeString(#""MESSAGE" "#) + self.writeMediaSubtype(message.message) + self.writeSpace()
            + self.writeBodyFields(fields) + self.writeSpace() + self.writeEnvelope(message.envelope)
            + self.writeSpace() + self.writeBody(message.body) + self.writeString(" \(message.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindBasic(
        mediaType: Media.MediaType,
        fields: BodyStructure.Fields
    ) -> Int {
        self.writeMediaType(mediaType) + self.writeSpace() + self.writeBodyFields(fields)
    }

    @discardableResult mutating func writeBodyExtensionSinglePart(_ ext: BodyStructure.Singlepart.Extension) -> Int {
        self.writeNString(ext.digest)
            + self.writeIfExists(ext.dispositionAndLanguage) { (dsp) -> Int in
                self.writeBodyDispositionAndLanguage(dsp)
            }
    }
}
