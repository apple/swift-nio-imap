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

import XCTest
import NIO
@testable import NIOIMAP

class BodyExtensionSinglepartTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyExtensionSinglepartTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.ExtensionSinglepart, String, UInt)] = [
            (.fieldMD5(nil, dspLanguage: nil), "NIL", #line),
            (.fieldMD5("md5", dspLanguage: nil), "\"md5\"", #line),
            (.fieldMD5("md5", dspLanguage: .fieldDSP(.string("string", parameter: []), fieldLanguage: nil)), "\"md5\" (\"string\" NIL)", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionSinglePart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
