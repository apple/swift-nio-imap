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

class Expire_Tests: EncodeTestClass {}

// MARK: - IMAP

extension Expire_Tests {
    func testEncode() {
        let inputs: [(Expire, String, UInt)] = [
            (
                .init(
                    dateTime: .init(
                        date: .init(year: 1234, month: 12, day: 34),
                        time: .init(hour: 12, minute: 34, second: 56, fraction: 123456)
                    )
                ),
                ";EXPIRE=1234-12-34T12:34:56.123456",
                #line
            )
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeExpire($0) })
    }

}
