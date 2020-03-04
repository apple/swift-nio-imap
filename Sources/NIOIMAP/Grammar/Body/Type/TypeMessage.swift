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

import NIO

extension NIOIMAP.Body {

    /// IMAPv4 `body-type-message`
    public struct TypeMessage: Equatable {
        public var message: NIOIMAP.Media.Message
        public var fields: Fields
        public var envelope: NIOIMAP.Envelope
        public var body: NIOIMAP.Body
        public var fieldLines: FieldLines

        /// Convenience function for a better experience when chaining multiple types.
        public static func message(_ message: NIOIMAP.Media.Message, fields: Fields, envelope: NIOIMAP.Envelope, body: NIOIMAP.Body, fieldLines: FieldLines) -> Self {
            return Self(message: message, fields: fields, envelope: envelope, body: body, fieldLines: fieldLines)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyTypeMessage(_ message: NIOIMAP.Body.TypeMessage) -> Int {
        self.writeMediaMessage(message.message) +
        self.writeSpace() +
        self.writeBodyFields(message.fields) +
        self.writeSpace() +
        self.writeEnvelope(message.envelope) +
        self.writeSpace() +
        self.writeBody(message.body) +
        self.writeString(" \(message.fieldLines)")
    }

}
