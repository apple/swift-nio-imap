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
    /// Represents a single-part body as defined in RFC 3501.
    public struct Singlepart: Hashable {
        /// The type of single-part. Note that "message" types may contain a multi-part.
        public var kind: Kind

        /// A collection of common message attributes, such as a message identifier.
        public var fields: Fields

        /// An optional extension to the core message. Not required to construct a valid message.
        public var `extension`: Extension?

        /// Creates a new `SinglePart`.
        /// - parameter type: The type of single-part. Note that "message" types may contain a multi-part.
        /// - parameter fields: A collection of common message attributes, such as a message identifier.
        /// - parameter extension: An optional extension to the core message. Not required to construct a valid message.
        public init(kind: BodyStructure.Singlepart.Kind, fields: Fields, extension: Extension? = nil) {
            self.kind = kind
            self.fields = fields
            self.extension = `extension`
        }
    }
}

// MARK: - Types

extension BodyStructure.Singlepart {
    /// Represents the type of a single-part message.
    public indirect enum Kind: Hashable {
        /// A simple message containing only one kind of data.
        case basic(Media.MediaType)

        /// A "full" email message containing an envelope, and a child body.
        case message(Message)

        /// A message type, for example plain text, or html.
        case text(Text)
    }

    /// Represents a typical "full" email message, containing an envelope and a child message.
    public struct Message: Hashable {
        /// The RFC 2045 sub-type. This will usually be `rfc822`.
        public var message: Media.Subtype

        /// The envelope of the message, potentially including the message sender, bcc list, etc.
        public var envelope: Envelope

        /// The child body. Note that this may be a multi-part.
        public var body: BodyStructure

        /// The number of lines in the message.
        public var lineCount: Int

        /// Creates a new `Message`.
        /// - parameter message:
        /// - parameter envelope: The envelope of the message
        /// - parameter body: The encapsulated message. Note that this may be a multi-part.
        /// - parameter lineCount: The number of lines in the message
        public init(message: Media.Subtype, envelope: Envelope, body: BodyStructure, lineCount: Int) {
            self.message = message
            self.envelope = envelope
            self.body = body
            self.lineCount = lineCount
        }
    }

    /// Represents a text-based message body.
    public struct Text: Hashable {
        /// The media sub-type of a text part, e.g. `html` or `plain` for `text/html` and `text/plain` respectively.
        public var mediaSubtype: Media.Subtype

        /// The number of lines in the message.
        public var lineCount: Int

        /// Creates a new `Text`.
        /// - parameter mediaText: The type of text message, e.g. `text/html` or `text/plain`
        /// - parameter lineCount: The number of lines in the message.
        public init(mediaSubtype: Media.Subtype, lineCount: Int) {
            self.mediaSubtype = mediaSubtype
            self.lineCount = lineCount
        }
    }

    /// Optional extension fields, initially pairing an MD5 body digest with a `DispositionAndLanguage`.
    public struct Extension: Hashable {
        /// A string giving the body MD5 value.
        public let digest: String?

        /// A `Disposition` and `LanguageLocation` pairing. `LanguageLocation` can be further expanded, the intention
        /// of which is to provide a cleaner API.
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Creates a new `Extension`
        /// - parameter fieldMD5: A string giving the body MD5 value.
        /// - parameter dispositionAndLanguage: An optional `Disposition` and `LanguageLocation` pairing.
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

    @discardableResult private mutating func writeBodyKindText(_ body: BodyStructure.Singlepart.Text, fields: BodyStructure.Fields) -> Int {
        self.writeString(#""TEXT" "#) +
            self.writeMediaSubtype(body.mediaSubtype) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeString(" \(body.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindMessage(_ message: BodyStructure.Singlepart.Message, fields: BodyStructure.Fields) -> Int {
        self.writeString(#""MESSAGE" "#) +
            self.writeMediaSubtype(message.message) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeSpace() +
            self.writeEnvelope(message.envelope) +
            self.writeSpace() +
            self.writeBody(message.body) +
            self.writeString(" \(message.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindBasic(mediaType: Media.MediaType, fields: BodyStructure.Fields) -> Int {
        self.writeMediaType(mediaType) +
            self.writeSpace() +
            self.writeBodyFields(fields)
    }

    @discardableResult mutating func writeBodyExtensionSinglePart(_ ext: BodyStructure.Singlepart.Extension) -> Int {
        self.writeNString(ext.digest) +
            self.writeIfExists(ext.dispositionAndLanguage) { (dsp) -> Int in
                self.writeBodyDispositionAndLanguage(dsp)
            }
    }
}
