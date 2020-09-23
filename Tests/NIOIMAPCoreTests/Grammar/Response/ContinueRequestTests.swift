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

class ContinueRequestTests: EncodeTestClass {}

// MARK: - Encoding

extension ContinueRequestTests {
    func testEncode() {
        let inputs: [(ContinueRequest, String, UInt)] = [
            (.data("a"), "+ YQ==\r\n", #line),
            (.responseText(.init(code: .alert, text: "text")), "+ [ALERT] text\r\n", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { req in
            var encoder = ResponseEncodeBuffer(buffer: self.testBuffer._buffer, options: ResponseEncodingOptions())
            defer {
                self.testBuffer = EncodeBuffer.serverEncodeBuffer(buffer: encoder.bytes, options: ResponseEncodingOptions())
            }
            return encoder.writeContinueRequest(req)
        })
    }
}
