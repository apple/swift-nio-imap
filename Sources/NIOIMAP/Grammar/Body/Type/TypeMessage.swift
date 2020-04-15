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
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyTypeMessage(_ message: IMAPCore.Body.TypeMessage) -> Int {
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
