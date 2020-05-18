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
    /// IMAPv4 `body-type-1part`
    public struct Singlepart: Equatable {
        public var type: Kind
        public var fields: Fields
        public var `extension`: Extension?

        public init(type: BodyStructure.Singlepart.Kind, fields: Fields, extension: Extension? = nil) {
            self.type = type
            self.fields = fields
            self.extension = `extension`
        }
    }
}

// MARK: - Types

extension BodyStructure.Singlepart {
    public indirect enum Kind: Equatable {
        case basic(Basic)
        case message(Message)
        case text(Text)
    }

    /// IMAPv4 `body-type-basic`
    public struct Basic: Equatable {
        public var media: Media.Basic

        public init(media: Media.Basic) {
            self.media = media
        }
    }

    /// IMAPv4 `body-type-message`
    public struct Message: Equatable {
        public var message: Media.Message
        public var envelope: Envelope
        public var body: BodyStructure
        public var fieldLines: Int

        public init(message: Media.Message, envelope: Envelope, body: BodyStructure, fieldLines: Int) {
            self.message = message
            self.envelope = envelope
            self.body = body
            self.fieldLines = fieldLines
        }
    }

    /// IMAPv4 `body-type-text`
    public struct Text: Equatable {
        public var mediaText: String
        public var lines: Int

        public init(mediaText: String, lines: Int) {
            self.mediaText = mediaText
            self.lines = lines
        }
    }

    /// IMAPv4 `body-ext-1part`
    public struct Extension: Equatable {
        public let fieldMD5: NString
        public var dspLanguage: BodyStructure.FieldDispositionLanguage?

        /// Convenience function for a better experience when chaining multiple types.
        init(fieldMD5: NString, dspLanguage: BodyStructure.FieldDispositionLanguage?) {
            self.fieldMD5 = fieldMD5
            self.dspLanguage = dspLanguage
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyTypeSinglepart(_ part: BodyStructure.Singlepart) -> Int {
        var size = 0
        switch part.type {
        case .basic(let basic):
            size += self.writeBodyTypeBasic(basic, fields: part.fields)
        case .message(let message):
            size += self.writeBodyTypeMessage(message, fields: part.fields)
        case .text(let text):
            size += self.writeBodyTypeText(text, fields: part.fields)
        }

        if let ext = part.extension {
            size += self.writeSpace()
            size += self.writeBodyExtensionSinglePart(ext)
        }
        return size
    }

    @discardableResult private mutating func writeBodyTypeText(_ body: BodyStructure.Singlepart.Text, fields: BodyStructure.Fields) -> Int {
        self.writeMediaText(body.mediaText) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeString(" \(body.lines)")
    }

    @discardableResult private mutating func writeBodyTypeMessage(_ message: BodyStructure.Singlepart.Message, fields: BodyStructure.Fields) -> Int {
        self.writeMediaMessage(message.message) +
            self.writeSpace() +
            self.writeBodyFields(fields) +
            self.writeSpace() +
            self.writeEnvelope(message.envelope) +
            self.writeSpace() +
            self.writeBody(message.body) +
            self.writeString(" \(message.fieldLines)")
    }

    @discardableResult private mutating func writeBodyTypeBasic(_ body: BodyStructure.Singlepart.Basic, fields: BodyStructure.Fields) -> Int {
        self.writeMediaBasic(body.media) +
            self.writeSpace() +
            self.writeBodyFields(fields)
    }

    @discardableResult mutating func writeBodyExtensionSinglePart(_ ext: BodyStructure.Singlepart.Extension) -> Int {
        self.writeNString(ext.fieldMD5) +
            self.writeIfExists(ext.dspLanguage) { (dspLanguage) -> Int in
                self.writeBodyFieldDispositionLanguage(dspLanguage)
            }
    }
}
