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

extension Media {
    /// Indicates if the media type conforms to a given standard
    public enum Message: String, Equatable {
        /// The media type conforms to RFC822.
        case rfc822 = "RFC822"
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeMediaMessage(_ message: Media.Message) -> Int {
        self._writeString("\"MESSAGE\" \"\(message.rawValue)\"")
    }
}
