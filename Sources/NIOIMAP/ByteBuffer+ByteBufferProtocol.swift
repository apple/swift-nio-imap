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

extension ByteBuffer: ByteBufferProtocol {
    
    public typealias EndiannessType = Endianness
    public typealias ReadableBytesViewType = ByteBufferView
    
    public func asString() -> String {
        return String(buffer: self)
    }
}

extension ByteBufferView: ByteBufferProtocolView {
    
}

extension Endianness: EndiannessProtocol {
    public static func bigEndian() -> Endianness {
        return .big
    }
    
    public static func littleEndian() -> Endianness {
        return .little
    }
}
