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
        _ = other.withUnsafeBytes { buffer in
            writeBytes(buffer)
        }
    }

    init(_ other: String) {
        self.init(other.data(using: .utf8)!)
    }
}

extension Data {
    init(_ other: ByteBuffer) {
        var o = other
        var d: Data!
        _ = o.readWithUnsafeReadableBytes { buffer in
            d = Data(buffer)
            return 0
        }
        self = d!
    }
}
