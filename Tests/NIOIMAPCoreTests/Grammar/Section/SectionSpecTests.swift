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

class SectionSpecifierTests: EncodeTestClass {}

// MARK: - SectionSpecifierTests imapEncoded

extension SectionSpecifierTests {
    func testIMAPEncoded_optional_none() {
        let expected = ""
        let size = self.testBuffer.writeSectionSpecifier(nil)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_text() {
        let expected = "HEADER"
        let size = self.testBuffer.writeSectionSpecifier(.init(kind: .header))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_part_notext() {
        let expected = "1.2.3.4"
        let size = self.testBuffer.writeSectionSpecifier(.init(part: [1, 2, 3, 4], kind: .complete))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_part_sometext() {
        let expected = "1.2.3.4.HEADER"
        let size = self.testBuffer.writeSectionSpecifier(.init(part: [1, 2, 3, 4], kind: .header))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Comparable

extension SectionSpecifierTests {
    func testComparable() {
        let inputs: [(SectionSpecifier, SectionSpecifier, Bool, UInt)] = [
            (.init(kind: .header), .init(kind: .text), true, #line),
            (.init(kind: .text), .init(kind: .text), false, #line),
            (.init(part: [1], kind: .complete), .init(part: [1], kind: .complete), false, #line),
            (.init(part: [1, 2], kind: .complete), .init(part: [1], kind: .complete), false, #line),
            (.init(part: [1, 2], kind: .complete), .init(part: [1, 2, 3], kind: .complete), true, #line),
            (.init(part: [1, 2, 3], kind: .complete), .init(part: [1, 2, 3], kind: .text), true, #line),
            (.init(part: [1, 2], kind: .text), .init(part: [1, 2, 3], kind: .header), true, #line),
        ]
        inputs.forEach { (lhs, rhs, expected, line) in
            XCTAssertEqual(lhs < rhs, expected, line: line)
        }
    }

    func testComparable_kind() {
        let inputs: [(SectionSpecifier.Kind, SectionSpecifier.Kind, Bool, UInt)] = [
            (.complete, .complete, false, #line),
            (.complete, .header, true, #line),
            (.complete, .headerFields([]), true, #line),
            (.complete, .headerFieldsNot([]), true, #line),
            (.complete, .MIMEHeader, true, #line),
            (.complete, .text, true, #line),
            (.header, .complete, true, #line),
            (.header, .header, true, #line),
            (.header, .headerFields([]), true, #line),
            (.header, .headerFieldsNot([]), true, #line),
            (.header, .MIMEHeader, true, #line),
            (.header, .text, true, #line),
            (.headerFields([]), .complete, false, #line),
            (.headerFields([]), .header, false, #line),
            (.headerFields([]), .headerFields([]), false, #line),
            (.headerFields([]), .headerFieldsNot([]), false, #line),
            (.headerFields([]), .MIMEHeader, false, #line),
            (.headerFields([]), .text, true, #line),
            (.headerFieldsNot([]), .complete, false, #line),
            (.headerFieldsNot([]), .header, false, #line),
            (.headerFieldsNot([]), .headerFields([]), false, #line),
            (.headerFieldsNot([]), .headerFieldsNot([]), false, #line),
            (.headerFieldsNot([]), .MIMEHeader, false, #line),
            (.headerFieldsNot([]), .text, true, #line),
            (.MIMEHeader, .complete, false, #line),
            (.MIMEHeader, .header, true, #line),
            (.MIMEHeader, .headerFields([]), true, #line),
            (.MIMEHeader, .headerFieldsNot([]), true, #line),
            (.MIMEHeader, .MIMEHeader, false, #line),
            (.MIMEHeader, .text, true, #line),
            (.text, .complete, false, #line),
            (.text, .header, false, #line),
            (.text, .headerFields([]), false, #line),
            (.text, .headerFieldsNot([]), false, #line),
            (.text, .MIMEHeader, false, #line),
            (.text, .text, false, #line),
        ]
        inputs.forEach { (lhs, rhs, expected, line) in
            XCTAssertEqual(lhs < rhs, expected, line: line)
        }
    }

    func testComparable_part() {
        let inputs: [(SectionSpecifier.Part, SectionSpecifier.Part, Bool, UInt)] = [
            ([1], [1], false, #line),
            ([1], [1, 2], true, #line),
            ([1, 2], [1], false, #line),
            ([1, 2, 3, 4], [1, 2, 3, 4], false, #line),
            ([1, 2, 3, 4], [1, 2, 3, 4, 5, 6], true, #line),
            ([1, 2, 3, 4, 5, 6], [1, 2, 3], false, #line),
        ]
        inputs.forEach { (lhs, rhs, expected, line) in
            XCTAssertEqual(lhs < rhs, expected, line: line)
        }
    }
}

// MARK: - Helpers

extension SectionSpecifierTests {
    func testDropFirst() {
        let inputs: [(SectionSpecifier.Part, SectionSpecifier.Part, UInt)] = [
            ([], [], #line),
            ([5], [], #line),
            ([5, 3], [3], #line),
            ([5, 3, 8], [3, 8], #line),
        ]
        inputs.forEach { (part, expected, line) in
            XCTAssertEqual(part.dropFirst(), expected, line: line)
        }
    }

    func testDropLast() {
        let inputs: [(SectionSpecifier.Part, SectionSpecifier.Part, UInt)] = [
            ([], [], #line),
            ([5], [], #line),
            ([5, 3], [5], #line),
            ([5, 3, 8], [5, 3], #line),
        ]
        inputs.forEach { (part, expected, line) in
            XCTAssertEqual(part.dropLast(), expected, line: line)
        }
    }

    func testAppending() {
        let inputs: [(SectionSpecifier.Part, Int, SectionSpecifier.Part, UInt)] = [
            ([], 1, [1], #line),
            ([5, 3, 8], 4, [5, 3, 8, 4], #line),
        ]
        inputs.forEach { (part, new, expected, line) in
            XCTAssertEqual(part.appending(new), expected, line: line)
        }
    }

    func testIsSubPartOf() {
        let inputs: [(SectionSpecifier.Part, SectionSpecifier.Part, Bool, UInt)] = [
            ([], [], false, #line),
            ([2, 3], [2, 3], false, #line),
            ([2, 3, 1], [2, 3], true, #line),
            ([2, 3], [2, 3, 1], false, #line),
            ([2, 3, 1, 7], [2, 3], true, #line),
            ([2, 3, 1, 7], [2, 3, 1], true, #line),
            ([2, 4, 1, 7], [2, 3], false, #line),
            ([5, 3, 1, 7], [2, 3], false, #line),
        ]
        inputs.forEach { (part, other, expected, line) in
            XCTAssertEqual(part.isSubPart(of: other), expected, line: line)
        }
    }

    func testIsChildPartOf() {
        let inputs: [(SectionSpecifier.Part, SectionSpecifier.Part, Bool, UInt)] = [
            ([], [], false, #line),
            ([], [1], false, #line),
            ([], [8], false, #line),
            ([1], [], true, #line),
            ([8], [], true, #line),
            ([2, 3], [2, 3], false, #line),
            ([2, 3, 1], [2, 3], true, #line),
            ([2, 3, 1], [4, 3], false, #line),
            ([2, 3, 1], [2, 7], false, #line),
            ([2, 3, 1, 4], [2, 3], false, #line),
            ([2, 3], [2, 3, 1], false, #line),
            ([2, 3, 1, 7], [2, 3], false, #line),
            ([2, 3, 1, 7], [2, 3, 1], true, #line),
            ([2, 4, 1, 7], [2, 3], false, #line),
            ([5, 3, 1, 7], [2, 3], false, #line),
        ]
        inputs.forEach { (part, other, expected, line) in
            XCTAssertEqual(part.isChildPart(of: other), expected, line: line)
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension SectionSpecifierTests {
    func testCustomDebugStringConvertible_part() {
        let inputs: [(SectionSpecifier.Part, String, UInt)] = [
            ([], "", #line),
            ([1], "1", #line),
            ([1, 2], "1.2", #line),
            ([1, 2, 3, 4], "1.2.3.4", #line),
        ]
        inputs.forEach { (part, expected, line) in
            XCTAssertEqual("\(part)", expected, line: line)
        }
    }
}
