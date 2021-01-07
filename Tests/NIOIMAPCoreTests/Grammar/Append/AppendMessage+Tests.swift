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

class AppendMessage_Tests: EncodeTestClass {}

extension AppendMessage_Tests {
    func testEncode() {
        let inputs: [(AppendMessage, CommandEncodingOptions, [String], UInt)] = [
            (.init(options: .init(flagList: [], internalDate: nil, extensions: []), data: .init(byteCount: 123)), .rfc3501, [" {123}\r\n"], #line),
            (.init(options: .init(flagList: [.draft, .flagged], internalDate: nil, extensions: []), data: .init(byteCount: 123)), .rfc3501, [" (\\Draft \\Flagged) {123}\r\n"], #line),
            (.init(options: .init(flagList: [.draft, .flagged], internalDate: InternalDate(.init(year: 2020, month: 7, day: 2, hour: 13, minute: 42, second: 52, zoneMinutes: 60)!), extensions: []), data: .init(byteCount: 123)), .rfc3501, [" (\\Draft \\Flagged) \"2-Jul-2020 13:42:52 +0100\" {123}\r\n"], #line),
            (.init(options: .init(flagList: [], internalDate: InternalDate(.init(year: 2020, month: 7, day: 2, hour: 13, minute: 42, second: 52, zoneMinutes: 60)!), extensions: []), data: .init(byteCount: 456)), .literalPlus, [" \"2-Jul-2020 13:42:52 +0100\" {456+}\r\n"], #line),
            (.init(options: .init(flagList: [], internalDate: nil, extensions: []), data: .init(byteCount: 456)), .literalPlus, [" {456+}\r\n"], #line),
        ]

        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAppendMessage($0) })
    }
}
