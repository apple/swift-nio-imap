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

class FullDateTime_Tests: EncodeTestClass {}

// MARK: - IMAP

extension FullDateTime_Tests {
    func testEncode_fullDateTime() {
        let inputs: [(FullDateTime, String, UInt)] = [
            (.init(date: .init(year: 1, month: 2, day: 3), time: .init(hour: 4, minute: 5, second: 6)), "0001-02-03T04:05:06", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFullDateTime($0) })
    }

    func testEncode_fullDate() {
        let inputs: [(FullDate, String, UInt)] = [
            (.init(year: 1, month: 2, day: 3), "0001-02-03", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFullDate($0) })
    }

    func testEncode_fullTime() {
        let inputs: [(FullTime, String, UInt)] = [
            (.init(hour: 1, minute: 2, second: 3), "01:02:03", #line),
            (.init(hour: 1, minute: 2, second: 3, fraction: 4), "01:02:03.4", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFullTime($0) })
    }
}
