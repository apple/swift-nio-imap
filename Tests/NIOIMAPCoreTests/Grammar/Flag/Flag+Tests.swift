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

class Flag_Tests: EncodeTestClass {}

// MARK: - init

extension Flag_Tests {
    // test a couple of cases to make sure that extensions are converted into non-extensions when appropriate
    // test that casing doesn't matter
    func testInit_extension() {
        let inputs: [(Flag, Flag, UInt)] = [
            (.extension("\\ANSWERED"), .answered, #line),
            (.extension("\\answered"), .answered, #line),
            (.extension("\\deleted"), .deleted, #line),
            (.extension("\\seen"), .seen, #line),
            (.extension("\\draft"), .draft, #line),
            (.extension("\\flagged"), .flagged, #line),
        ]

        for (test, expected, line) in inputs {
            XCTAssertEqual(test, expected, line: line)
        }
    }

    func testEquality() {
        func AssertEqualAndEqualHash(_ flagA: Flag, _ flagB: Flag, line: UInt = #line) {
            func hash(_ flag: Flag) -> Int {
                var hasher = Hasher()
                flag.hash(into: &hasher)
                return hasher.finalize()
            }
            XCTAssertEqual(flagA, flagB, line: line)
            XCTAssertEqual(flagA.hashValue, flagB.hashValue, "hashValue", line: line)
            XCTAssertEqual(hash(flagA), hash(flagB), "hash(into:)", line: line)
        }

        AssertEqualAndEqualHash(.answered, .answered)
        AssertEqualAndEqualHash(.flagged, .flagged)
        AssertEqualAndEqualHash(.deleted, .deleted)
        AssertEqualAndEqualHash(.seen, .seen)
        AssertEqualAndEqualHash(.draft, .draft)
        AssertEqualAndEqualHash(.keyword(.colorBit0), .keyword(.colorBit0))
        AssertEqualAndEqualHash(.keyword(.junk), .keyword(.junk))
        AssertEqualAndEqualHash(.keyword(.unregistered_junk), .keyword(.unregistered_junk))
        AssertEqualAndEqualHash(.keyword(Flag.Keyword("FooBar")), .keyword(Flag.Keyword("FooBar")))
        AssertEqualAndEqualHash(.extension("\\FooBar"), .extension("\\FooBar"))
        AssertEqualAndEqualHash(.answered, .extension("\\Answered"))

        // Case-insensitive:
        AssertEqualAndEqualHash(.answered, .extension("\\ANSWERED"))
        AssertEqualAndEqualHash(.answered, .extension("\\answered"))
        AssertEqualAndEqualHash(.keyword(Flag.Keyword("foobar")), .keyword(Flag.Keyword("FOOBAR")))
        AssertEqualAndEqualHash(.keyword(Flag.Keyword("FOOBAR")), .keyword(Flag.Keyword("foobar")))
        AssertEqualAndEqualHash(.keyword(Flag.Keyword("FOOBAR")), .keyword(Flag.Keyword("FooBar")))
        AssertEqualAndEqualHash(.extension("\\foobar"), .extension("\\FOOBAR"))
        AssertEqualAndEqualHash(.extension("\\FOOBAR"), .extension("\\foobar"))
        AssertEqualAndEqualHash(.extension("\\FOOBAR"), .extension("\\FooBar"))
    }

    func testInequality() {
        func AssertNotEqual(_ flagA: Flag, _ flagB: Flag, line: UInt = #line) {
            XCTAssertNotEqual(flagA, flagB, line: line)
        }

        AssertNotEqual(.answered, .flagged)
        AssertNotEqual(.answered, .deleted)
        AssertNotEqual(.answered, .seen)
        AssertNotEqual(.answered, .draft)
        AssertNotEqual(.answered, .keyword(.colorBit0))
        AssertNotEqual(.answered, .keyword(.junk))
        AssertNotEqual(.answered, .keyword(.unregistered_junk))
        AssertNotEqual(.answered, .keyword(Flag.Keyword("FooBar")))
        AssertNotEqual(.answered, .extension("\\FooBar"))

        AssertNotEqual(.extension("\\Baz"), .answered)
        AssertNotEqual(.extension("\\Baz"), .flagged)
        AssertNotEqual(.extension("\\Baz"), .deleted)
        AssertNotEqual(.extension("\\Baz"), .seen)
        AssertNotEqual(.extension("\\Baz"), .draft)
        AssertNotEqual(.extension("\\Baz"), .keyword(.colorBit0))
        AssertNotEqual(.extension("\\Baz"), .keyword(.junk))
        AssertNotEqual(.extension("\\Baz"), .keyword(.unregistered_junk))
        AssertNotEqual(.extension("\\Baz"), .keyword(Flag.Keyword("FooBar")))
        AssertNotEqual(.extension("\\Baz"), .extension("\\FooBar"))
        AssertNotEqual(.extension("\\Baz"), .extension("\\Answered"))

        AssertNotEqual(.keyword(.notJunk), .answered)
        AssertNotEqual(.keyword(.notJunk), .flagged)
        AssertNotEqual(.keyword(.notJunk), .deleted)
        AssertNotEqual(.keyword(.notJunk), .seen)
        AssertNotEqual(.keyword(.notJunk), .draft)
        AssertNotEqual(.keyword(.notJunk), .keyword(.colorBit0))
        AssertNotEqual(.keyword(.notJunk), .keyword(.junk))
        AssertNotEqual(.keyword(.notJunk), .keyword(.unregistered_junk))
        AssertNotEqual(.keyword(.notJunk), .keyword(Flag.Keyword("FooBar")))
        AssertNotEqual(.keyword(.notJunk), .extension("\\FooBar"))
        AssertNotEqual(.keyword(.notJunk), .extension("\\Answered"))
    }
}

// MARK: - Encoding

extension Flag_Tests {
    func testEncode() {
        let inputs: [(Flag, String, UInt)] = [
            (.answered, "\\Answered", #line),
            (.deleted, "\\Deleted", #line),
            (.draft, "\\Draft", #line),
            (.flagged, "\\Flagged", #line),
            (.seen, "\\Seen", #line),
            (.keyword(.forwarded), "$Forwarded", #line),
            // Case insensitive, but case preserving:
            (.extension("\\extension"), "\\extension", #line),
            (.extension("\\Extension"), "\\Extension", #line),
            (.extension("\\EXTENSION"), "\\EXTENSION", #line),
            (.keyword(Flag.Keyword("$extension")), "$extension", #line),
            (.keyword(Flag.Keyword("$Extension")), "$Extension", #line),
            (.keyword(Flag.Keyword("$EXTENSION")), "$EXTENSION", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFlag(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
