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

import Foundation
import NIO
@testable import NIOIMAPCore
import XCTest

class EncodeBuffer_Tests: XCTestCase {}

// MARK: - hasMoreChunks

extension EncodeBuffer_Tests {
    func testHasMoreChunks() {
        let raw = ByteBufferAllocator().buffer(capacity: 20)
        var encodeBuffer = EncodeBuffer(raw, mode: .client, capabilities: [])
        XCTAssertFalse(encodeBuffer.hasMoreChunks)
        encodeBuffer.writeCommand(.init(tag: "tag", command: .noop))
        XCTAssertTrue(encodeBuffer.hasMoreChunks)
        _ = encodeBuffer.nextChunk()
        XCTAssertFalse(encodeBuffer.hasMoreChunks)
    }
}
