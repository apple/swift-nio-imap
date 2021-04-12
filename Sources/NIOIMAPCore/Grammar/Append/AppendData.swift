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

/// A description of the data that will be sent as part of an append command.
public struct AppendData: Equatable {
    /// The size of the message in bytes.
    public var byteCount: Int

    /// `true` if the message data is sent without a content transfer encoding, i.e. as binary data, See RFC 3516.
    ///
    /// When this is `true` the APPEND command will use the `<literal8>` syntax as defined in RFC 3516.
    public var withoutContentTransferEncoding: Bool

    /// Creates a new `AppendMetadata`.
    /// - parameter byteCount: The size of the message in bytes.
    /// - parameter withoutContentTransferEncoding: `true` if the bytes are sent without a content transfer encoding. Defaults to `false`.
    public init(byteCount: Int, withoutContentTransferEncoding: Bool = false) {
        self.byteCount = byteCount
        self.withoutContentTransferEncoding = withoutContentTransferEncoding
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeAppendData(_ data: AppendData) -> Int {
        guard case .client(let options) = mode else { preconditionFailure("Trying to send command, but not in 'client' mode.") }
        switch (options.useNonSynchronizingLiteralPlus, data.withoutContentTransferEncoding) {
        case (true, true):
            return self._writeString("~{\(data.byteCount)+}\r\n")
        case (_, true):
            let size = self._writeString("~{\(data.byteCount)}\r\n")
            self.markStopPoint()
            return size
        case (true, _):
            return self._writeString("{\(data.byteCount)+}\r\n")
        default:
            let size = self._writeString("{\(data.byteCount)}\r\n")
            self.markStopPoint()
            return size
        }
    }
}
