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

class ModifiedUTF7_Tests: XCTestCase {}

extension ModifiedUTF7_Tests {
    func testEncode() {
        let inputs: [(String, String, UInt)] = [
            ("", "", #line),
            ("abc", "abc", #line),
            ("&", "&-", #line),
            ("ab&12", "ab&-12", #line),
            ("mail/€/£", "mail/&IKw-/&AKM-", #line),
            ("Répertoire", "R&AOk-pertoire", #line),
            ("パリ", "&MNEw6g-", #line),
            ("雑件", "&ltFO9g-", #line),
            ("🏣🏣", "&2Dzf49g83+M-", #line),
            ("🧑🏽‍🦳", "&2D7d0dg83,0gDdg+3bM-", #line),
            ("a/b/c", "a/b/c", #line),
            (#"a\b\c"#, #"a\b\c"#, #line),
            ("a+b", "a+b", #line),
            ("~ab", "~ab", #line),
        ]
        for (input, expected, line) in inputs {
            let actual = ModifiedUTF7.encode(input)
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
            ("&MNEw6g-", "パリ", #line),
            ("&ltFO9g-", "雑件", #line),
            ("&2Dzf49g83+M-", "🏣🏣", #line),
            ("&2D7d0dg83,0gDdg+3bM-", "🧑🏽‍🦳", #line),
            ("a/b/c", "a/b/c", #line),
            (#"a\b\c"#, #"a\b\c"#, #line),
            ("a+b", "a+b", #line),
            ("~ab", "~ab", #line),
        ]
        for (input, expected, line) in inputs {
            XCTAssertNoThrow(XCTAssertEqual(expected, try ModifiedUTF7.decode(ByteBuffer(string: input)), line: line), line: line)
        }
    }

    func testDecode_error() {
        XCTAssertThrowsError(try ModifiedUTF7.decode(ByteBuffer(string: "&aa==-"))) { e in
            XCTAssertTrue(e is ModifiedUTF7.DecodingError)
        }
    }

    func testValidate() {
        XCTAssertNoThrow(try ModifiedUTF7.validate("a"))
        XCTAssertNoThrow(try ModifiedUTF7.validate("a/b/c"))
        XCTAssertNoThrow(try ModifiedUTF7.validate("&2Dzf49g83+M-"))
        XCTAssertNoThrow(try ModifiedUTF7.validate("&ltFO9g-"))
    }
}
