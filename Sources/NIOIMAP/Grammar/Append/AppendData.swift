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

extension NIOIMAP {

    public struct AppendData: Equatable {
        public init(byteCount: Int, needs8BitCleanTransport: Bool = false, synchronizing: Bool = true) {
            self.byteCount = byteCount
            self.synchronizing = synchronizing
            self.needs8BitCleanTransport = needs8BitCleanTransport
        }

        public var byteCount: Int

        /// `true` is the client needs to wait for the server to send a _command continuation request_ before sending
        /// the actual data.
        ///
        /// `false` is only valid if the server advertised the [`LITERAL+`](https://tools.ietf.org/html/rfc2088)
        /// capability.
        public var synchronizing: Bool

        /// `true` if the data to follow may contain `\0` bytes.
        ///
        /// `true` is only valid if the server advertised the [`BINARY`](https://tools.ietf.org/html/rfc3516)
        /// capability.
        public var needs8BitCleanTransport: Bool
    }
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAppendData(_ data: NIOIMAP.AppendData) -> Int {
        self.writeString("\(data.needs8BitCleanTransport ? "~" : ""){\(data.byteCount)\(data.synchronizing ? "" : "+")}\r\n")
    }
}
