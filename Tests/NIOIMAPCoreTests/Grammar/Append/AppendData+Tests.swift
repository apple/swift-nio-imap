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

class AppendData_Tests: EncodeTestClass {}

extension AppendData_Tests {
    func testEncode() {
        let inputs: [(AppendData, CommandEncodingOptions, [String], UInt)] = [
            (.init(byteCount: 123), .rfc3501, ["{123}\r\n"], #line),
            (.init(byteCount: 456, withoutContentTransferEncoding: true), .rfc3501, ["~{456}\r\n"], #line),
            (.init(byteCount: 123), .literalPlus, ["{123+}\r\n"], #line),
            (.init(byteCount: 456, withoutContentTransferEncoding: true), .literalPlus, ["~{456+}\r\n"], #line),
        ]

        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAppendData($0) })
    }
}
