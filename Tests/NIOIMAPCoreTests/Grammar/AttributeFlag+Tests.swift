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

class AttributeFlag_Tests: EncodeTestClass {}

// MARK: - Encoding

extension AttributeFlag_Tests {
    func testEncoding() {
        let inputs: [(AttributeFlag, String, UInt)] = [
            (.answered, "\\\\answered", #line),
            (.deleted, "\\\\deleted", #line),
            (.draft, "\\\\draft", #line),
            (.flagged, "\\\\flagged", #line),
            (.seen, "\\\\seen", #line),
            (.init(rawValue: "test"), "test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAttributeFlag($0) })
    }

    func testLowercased() {
        let t1 = AttributeFlag(rawValue: "TEST")
        let t2 = AttributeFlag(rawValue: "test")
        XCTAssertEqual(t1, t2)
        XCTAssertEqual(t1.rawValue, "test")
        XCTAssertEqual(t2.rawValue, "test")
    }
}
