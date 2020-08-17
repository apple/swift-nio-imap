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

class UTF7_Tests: XCTestCase {}

extension UTF7_Tests {
    func testEncode() {
        let inputs: [(String, String, UInt)] = [
            ("", "", #line),
            ("abc", "abc", #line),
            ("&", "&-", #line),
            ("ab&12", "ab&-12", #line),
            ("mail/€/£", "mail/&IKw-/&AKM-", #line),
            ("Répertoire", "R&AOk-pertoire", #line),
        ]
        for (input, expected, line) in inputs {
            let actual = UTF7.encode(input)
            XCTAssertEqual(expected, String(buffer: actual), line: line)
        }
    }

    func testDecode() {
        let inputs: [(String, String, UInt)] = [
            ("", "", #line),
            ("abc", "abc", #line),
            ("&-", "&", #line),
            ("ab&-12", "ab&12", #line),
            ("mail/&IKw-/&AKM-", "mail/€/£", #line),
            ("R&AOk-pertoire", "Répertoire", #line),
        ]
        for (input, expected, line) in inputs {
            let actual = try! UTF7.decode(ByteBuffer(string: input))
            XCTAssertEqual(expected, actual, line: line)
        }
    }
}
