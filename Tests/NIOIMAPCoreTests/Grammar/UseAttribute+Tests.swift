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

class UseAttribute_Tests: EncodeTestClass {}

// MARK: - Encoding

extension UseAttribute_Tests {
    func testEncode() {
        let inputs: [(UseAttribute, String, UInt)] = [
            (.all, "\\all", #line),
            (.archive, "\\archive", #line),
            (.drafts, "\\drafts", #line),
            (.flagged, "\\flagged", #line),
            (.junk, "\\junk", #line),
            (.sent, "\\sent", #line),
            (.trash, "\\trash", #line),
            (.init(rawValue: "\\test"), "\\test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUseAttribute($0) })
    }

    func testLowercasing() {
        let t1 = UseAttribute(rawValue: "TEST")
        let t2 = UseAttribute(rawValue: "test")
        XCTAssertEqual(t1, t2)
        XCTAssertEqual(t1.rawValue, "test")
        XCTAssertEqual(t2.rawValue, "test")
    }
}
