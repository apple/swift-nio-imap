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
    public struct Singlepart: Equatable {

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
        public init(type: BodyStructure.Singlepart.Kind, fields: Fields, extension: Extension? = nil) {
            self.kind = type
            self.fields = fields
            self.extension = `extension`
        }
    }
}

// MARK: - Types

extension BodyStructure.Singlepart {

    /// Represents the type of a single-part message.
    public indirect enum Kind: Equatable {

        /// A simple message containing only one kind of data.
        case basic(Media.Basic)

        /// A "full" email message containing an envelope, and a child body.
        case message(Message)

        /// A message type, for example plain text, or html.
        case text(Text)
    }

    /// Represents a typical "full" email message, containing an envelope and a child message.
    public struct Message: Equatable {
        /// Indication if the message contains an encapsulated message.
        public var message: Media.Message

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
        /// - parameter fieldLines: The number of lines in the message
        public init(message: Media.Message, envelope: Envelope, body: BodyStructure, fieldLines: Int) {
            self.message = message
            self.envelope = envelope
            self.body = body
            self.lineCount = fieldLines
        }
    }

    /// Represents a text-based message body.
    public struct Text: Equatable {
        /// The type of text message, e.g. `text/html` or `text/plain`
        public var mediaText: String

        /// The number of lines in the message.
        public var lineCount: Int

        /// Creates a new `Text`.
        /// - parameter mediaText: The type of text message, e.g. `text/html` or `text/plain`
        /// - parameter lineCount: The number of lines in the message.
        public init(mediaText: String, lineCount: Int) {
            self.mediaText = mediaText
            self.lineCount = lineCount
        }
    }

    /// Optional extension fields, initially pairing an MD5 body digest with a `DispositionAndLanguage`.
    public struct Extension: Equatable {
        /// A string giving the body MD5 value.
        public let digest: String?

        /// A `Disposition` and `LanguageLocation` pairing. `LanguageLocation` can be further expanded, the intention
        /// of which is to provide a cleaner API.
        public var dispositionAndLanguage: BodyStructure.DispositionAndLanguage?

        /// Creates a new `Extension`
        /// - parameter fieldMD5: A string giving the body MD5 value.
        /// - parameter dispositionAndLanguage: An optional `Disposition` and `LanguageLocation` pairing.
        init(fieldMD5: String?, dispositionAndLanguage: BodyStructure.DispositionAndLanguage?) {
            self.digest = fieldMD5
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
            size += self.writeBodyKindBasic(mediaKind: basic, fields: part.fields)
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
        self.writeMediaText(body.mediaText) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeString(" \(body.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindMessage(_ message: BodyStructure.Singlepart.Message, fields: BodyStructure.Fields) -> Int {
        self.writeMediaMessage(message.message) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeSpace() +
            self.writeEnvelope(message.envelope) +
            self.writeSpace() +
            self.writeBody(message.body) +
            self.writeString(" \(message.lineCount)")
    }

    @discardableResult private mutating func writeBodyKindBasic(mediaKind: Media.Basic, fields: BodyStructure.Fields) -> Int {
        self.writeMediaBasic(mediaKind) +
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
