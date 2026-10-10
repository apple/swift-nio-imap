//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO

extension ByteBuffer {
    init(_ other: Data) {
        self.init()
        // `Data` is a `Collection` of `UInt8`, so this needs no pointer access.
        writeBytes(other)
    }

    init(_ other: String) {
        self.init(other.data(using: .utf8)!)
    }
}

extension Data {
    init(_ other: ByteBuffer) {
        // `readableBytesView` is a `Collection` of the buffer's readable bytes.
        self.init(other.readableBytesView)
    }
}
