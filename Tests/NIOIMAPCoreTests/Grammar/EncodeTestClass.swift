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
@testable import NIOIMAPCore
import XCTest

class EncodeTestClass: XCTestCase {
    var testBuffer = EncodeBuffer(ByteBufferAllocator().buffer(capacity: 128), mode: .server(), capabilities: [])

    var testBufferString: String {
        var remaining = self.testBuffer
        let nextBit = remaining.nextChunk().bytes
        return String(buffer: nextBit)
    }

    override func setUp() {
        self.testBuffer = EncodeBuffer(ByteBufferAllocator().buffer(capacity: 128), mode: .server(), capabilities: [])
    }

    override func tearDown() {
        self.testBuffer.capabilities = []
    }

    func iterateInputs<T>(inputs: [(T, String, UInt)], encoder: (T) throws -> Int, file: StaticString = magicFile()) {
        self.iterateInputs(inputs: inputs.map { ($0.0, [], $0.1, $0.2) }, encoder: encoder, file: file)
    }

    func iterateInputs<T>(inputs: [(T, EncodingCapabilities, String, UInt)], encoder: (T) throws -> Int, file: StaticString = magicFile()) {
        for (test, capabilities, expectedString, line) in inputs {
            self.testBuffer.capabilities = capabilities
            self.testBuffer.clear()
            do {
                let size = try encoder(test)
                XCTAssertEqual(size, expectedString.utf8.count, file: file, line: line)
                XCTAssertEqual(self.testBufferString, expectedString, file: file, line: line)
            } catch {
                XCTFail("\(error)", file: file, line: line)
            }
        }
    }
}
