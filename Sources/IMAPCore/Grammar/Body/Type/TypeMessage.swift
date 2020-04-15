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



extension IMAPCore.Body {

    /// IMAPv4 `body-type-message`
    public struct TypeMessage: Equatable {
        public var message: IMAPCore.Media.Message
        public var fields: Fields
        public var envelope: IMAPCore.Envelope
        public var body: IMAPCore.Body
        public var fieldLines: Int

        /// Convenience function for a better experience when chaining multiple types.
        public static func message(_ message: IMAPCore.Media.Message, fields: Fields, envelope: IMAPCore.Envelope, body: IMAPCore.Body, fieldLines: Int) -> Self {
            return Self(message: message, fields: fields, envelope: envelope, body: body, fieldLines: fieldLines)
        }
    }

}
