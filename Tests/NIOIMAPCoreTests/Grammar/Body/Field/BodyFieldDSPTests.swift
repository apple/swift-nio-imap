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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class BodyFieldDSPTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyFieldDSPTests {
    func testEncode() {
        let inputs: [(BodyStructure.Disposition?, String, UInt)] = [
            (nil, "NIL", #line),
            (.init(kind: "some", parameters: ["f1": "v1"]), "(\"some\" (\"f1\" \"v1\"))", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyDisposition(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}

// MARK: - Convenience methods

extension BodyFieldDSPTests {
    func testSize() {
        let inputs: [(BodyStructure.Disposition, Int?, UInt)] = [
            (.init(kind: "test", parameters: [:]), nil, #line),
            (.init(kind: "test", parameters: ["size": "123"]), 123, #line),
            (.init(kind: "test", parameters: ["SIZE": "456"]), 456, #line),
            (.init(kind: "test", parameters: ["SIZE": "abc"]), nil, #line),
        ]

        for (dsp, expected, line) in inputs {
            XCTAssertEqual(dsp.size, expected, line: line)
        }
    }

    func testFilename() {
        let inputs: [(BodyStructure.Disposition, String?, UInt)] = [
            (.init(kind: "test", parameters: [:]), nil, #line),
            (.init(kind: "test", parameters: ["filename": "hello"]), "hello", #line),
            (.init(kind: "test", parameters: ["FILENAME": "world"]), "world", #line),
        ]

        for (dsp, expected, line) in inputs {
            XCTAssertEqual(dsp.filename, expected, line: line)
        }
    }
}
