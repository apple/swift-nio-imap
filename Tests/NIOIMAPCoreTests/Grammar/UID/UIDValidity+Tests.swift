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

class UIDValidity_Tests: EncodeTestClass {}

// MARK: - Encoding

extension UIDValidity_Tests {
    func testEncode() {
        let inputs: [(UIDValidity, String, UInt)] = [
            (123, "123", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUIDValidity($0) })
    }

    func testValidRange() {
        XCTAssertNil(UIDValidity(exactly: 0))
        XCTAssertEqual(UIDValidity(exactly: 1)?.rawValue, 1)
        XCTAssertEqual(UIDValidity(exactly: 4_294_967_295)?.rawValue, 4_294_967_295)
        XCTAssertNil(UIDValidity(exactly: 4_294_967_296))
    }
}
