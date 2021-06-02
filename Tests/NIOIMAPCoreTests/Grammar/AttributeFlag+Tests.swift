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
            (.init("test"), "test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAttributeFlag($0) })
    }

    func testLowercased() {
        let t1 = AttributeFlag("TEST")
        let t2 = AttributeFlag("test")
        XCTAssertEqual(t1, t2)
        XCTAssertEqual(t1.stringValue, "test")
        XCTAssertEqual(t2.stringValue, "test")
    }
}
