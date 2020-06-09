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

public struct AppendMessage: Equatable {
    public var options: AppendOptions
    public var data: AppendData

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
