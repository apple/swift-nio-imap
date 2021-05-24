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

class IUID_Tests: EncodeTestClass {}

// MARK: - Encoding

extension IUID_Tests {
    func testEncode_IUID() {
        let inputs: [(IUID, String, UInt)] = [
            (.init(uid: 123), "/;UID=123", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIUID($0) })
    }

    func testEncode_IUIDOnly() {
        let inputs: [(IUID, String, UInt)] = [
            (.init(uid: 123), ";UID=123", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIUIDOnly($0) })
    }
}
