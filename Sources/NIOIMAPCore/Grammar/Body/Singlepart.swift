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

extension NIOIMAP.BodyStructure {
    /// IMAPv4 `body-type-1part`
    public struct Singlepart: Equatable {
        public var type: Kind
        public var `extension`: ExtensionSinglepart?

        /// Convenience function for a better experience when chaining multiple types.
        public static func type(_ type: Kind, extension: ExtensionSinglepart?) -> Self {
            Self(type: type, extension: `extension`)
        }
    }
}

// MARK: - Types

extension NIOIMAP.BodyStructure.Singlepart {
    public indirect enum Kind: Equatable {
        case basic(Basic)
        case message(Message)
        case text(Text)
    }

    /// IMAPv4 `body-type-basic`
    public struct Basic: Equatable {
        public var media: NIOIMAP.Media.Basic
        public var fields: NIOIMAP.BodyStructure.Fields

        public static func media(_ media: NIOIMAP.Media.Basic, fields: NIOIMAP.BodyStructure.Fields) -> Self {
            Self(media: media, fields: fields)
        }
    }

    /// IMAPv4 `body-type-message`
    public struct Message: Equatable {
        public var message: NIOIMAP.Media.Message
        public var fields: NIOIMAP.BodyStructure.Fields
        public var envelope: NIOIMAP.Envelope
        public var body: NIOIMAP.BodyStructure
        public var fieldLines: Int

        /// Convenience function for a better experience when chaining multiple types.
        public static func message(_ message: NIOIMAP.Media.Message, fields: NIOIMAP.BodyStructure.Fields, envelope: NIOIMAP.Envelope, body: NIOIMAP.BodyStructure, fieldLines: Int) -> Self {
            Self(message: message, fields: fields, envelope: envelope, body: body, fieldLines: fieldLines)
        }
    }

    /// IMAPv4 `body-type-text`
    public struct Text: Equatable {
        public var mediaText: String
        public var fields: NIOIMAP.BodyStructure.Fields
        public var lines: Int

        public static func mediaText(_ mediaText: String, fields: NIOIMAP.BodyStructure.Fields, lines: Int) -> Self {
            Self(mediaText: mediaText, fields: fields, lines: lines)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyTypeSinglepart(_ part: NIOIMAP.BodyStructure.Singlepart) -> Int {
        var size = 0
        switch part.type {
        case .basic(let basic):
            size += self.writeBodyTypeBasic(basic)
        case .message(let message):
            size += self.writeBodyTypeMessage(message)
        case .text(let text):
            size += self.writeBodyTypeText(text)
        }

        if let ext = part.extension {
            size += self.writeSpace()
            size += self.writeBodyExtensionSinglePart(ext)
        }
        return size
    }

    @discardableResult mutating func writeBodyTypeText(_ body: NIOIMAP.BodyStructure.Singlepart.Text) -> Int {
        self.writeMediaText(body.mediaText) +
            self.writeSpace() +
            self.writeBodyFields(body.fields) +
            self.writeString(" \(body.lines)")
    }

    @discardableResult mutating func writeBodyTypeMessage(_ message: NIOIMAP.BodyStructure.Singlepart.Message) -> Int {
        self.writeMediaMessage(message.message) +
            self.writeSpace() +
            self.writeBodyFields(message.fields) +
            self.writeSpace() +
            self.writeEnvelope(message.envelope) +
            self.writeSpace() +
            self.writeBody(message.body) +
            self.writeString(" \(message.fieldLines)")
    }

    @discardableResult mutating func writeBodyTypeBasic(_ body: NIOIMAP.BodyStructure.Singlepart.Basic) -> Int {
        self.writeMediaBasic(body.media) +
            self.writeSpace() +
            self.writeBodyFields(body.fields)
    }
}
