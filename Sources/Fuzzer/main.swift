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
import NIOIMAP

@_cdecl("LLVMFuzzerTestOneInput") public func fuzzMe(data: UnsafePointer<CChar>, size: CInt) -> CInt {
    
    let bufferPointer = UnsafeBufferPointer(start: data, count: Int(size))
    var buffer = bufferPointer.withMemoryRebound(to: UInt8.self) {
        ByteBuffer(bytes: $0)
    }
    var parser = CommandParser()
    do {
        _ = try parser.parseCommandStream(buffer: &buffer)
    } catch {
        // do nothing
    }
    
    return 0
}

