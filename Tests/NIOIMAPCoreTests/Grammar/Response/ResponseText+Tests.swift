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

class ResponseText_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseText_Tests {
    func testEncode() {
        let inputs: [(ResponseText, String, UInt)] = [
            (.init(code: nil, text: "buffer"), "buffer", #line),
            (.init(code: .alert, text: "buffer"), "[ALERT] buffer", #line),

            // Must insert an additional space to make it standard conformant:
            (.init(code: nil, text: ""), " ", #line),
            (.init(code: .alert, text: ""), "[ALERT]  ", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeResponseText($0) })
    }

    func testDebugDescription() {
        XCTAssertEqual(
            ResponseText(code: nil, text: "buffer").debugDescription,
            "buffer"
        )
        XCTAssertEqual(
            ResponseText(code: .alert, text: "buffer").debugDescription,
            "[ALERT] buffer"
        )
    }
}
