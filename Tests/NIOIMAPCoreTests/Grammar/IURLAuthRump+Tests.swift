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

class IRumpAuthenticatedURL_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IRumpAuthenticatedURL_Tests {
    func testEncode() {
        let inputs: [(IRumpAuthenticatedURL, String, UInt)] = [
            (.init(access: .anonymous), ";URLAUTH=anonymous", #line),
            (
                .init(expire: .init(dateTime: .init(date: .init(year: 1234, month: 12, day: 23), time: .init(hour: 12, minute: 34, second: 56))), access: .authenticateUser),
                ";EXPIRE=1234-12-23T12:34:56;URLAUTH=authuser",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIRumpAuthenticatedURL($0) })
    }
}
