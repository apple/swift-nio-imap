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
@testable import NIOIMAPCore

class Capability_Tests: EncodeTestClass {

}

// MARK: - Equatable
extension Capability_Tests {
    
    func testEquatable() {
        let capability1 = NIOIMAP.Capability("idle")
        let capability2 = NIOIMAP.Capability("IDLE")
        XCTAssertEqual(capability1, capability2)
    }
    
}

// MARK: - Encoding
extension Capability_Tests {

    func testCapabilityData_encode() {

        let tests: [([NIOIMAP.Capability], String, UInt)] = [
            ([], "CAPABILITY IMAP4 IMAP4rev1", #line),
            ([.condStore], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE", #line),
            ([.condStore, .enable, .filters], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE ENABLE FILTERS", #line)
        ]

        for (data, expectedString, line) in tests {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCapabilityData(data)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }

    }

}
