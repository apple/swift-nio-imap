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

/// Metadata for a message that will be appended to a mailbox.
public struct AppendMessage: Equatable {
    /// A collection of non-essential options, such as any flags to be added to the message.
    public var options: AppendOptions

    /// Metadata for the data to be sent, such as the number of bytes.
    public var data: AppendData

    /// Creates a new `AppendMessage`.
    /// - parameter options: A collection of non-essential options, such as any flags to be added to the message.
    /// - parameter data: Metadata for the data to be sent, such as the number of bytes.
    public init(options: AppendOptions, data: AppendData) {
        self.options = options
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult public mutating func writeAppendMessage(_ message: AppendMessage) -> Int {
        self.writeAppendOptions(message.options) +
            self.writeSpace() +
            self.writeAppendData(message.data)
    }
}
