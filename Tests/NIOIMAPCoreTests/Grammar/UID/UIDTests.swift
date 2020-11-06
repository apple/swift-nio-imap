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

class UIDTests: EncodeTestClass {}

// MARK: - Integer literal

extension UIDTests {
    func testIntegerLiteral() {
        let num: UID = 5
        XCTAssertEqual(num, 5)
    }
}

// MARK: - Comparable

extension UIDTests {
    func testComparable() {
        XCTAssertFalse(UID.max < .max)
        XCTAssertFalse(UID.max < 999)
        XCTAssertTrue(UID.max > 999)
        XCTAssertTrue(UID(1) < 999) // use .number to force type
    }
}

// MARK: - Encoding

extension UIDTests {
    func testEncode_max() {
        let expected = "*"
        let size = self.testBuffer.writeUID(.max)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testEncode_number() {
        let expected = "1234"
        let size = self.testBuffer.writeUID(1234)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Codable

extension UIDTests {
    func testRoundTripCodable() {
        XCTAssertEqual(try TestUtilities.roundTripCodable(XCTUnwrap(UID(rawValue: 1))), try XCTUnwrap(UID(rawValue: 1)))
        XCTAssertEqual(try TestUtilities.roundTripCodable(XCTUnwrap(UID(rawValue: 45_678))), try XCTUnwrap(UID(rawValue: 45_678)))
        XCTAssertEqual(try TestUtilities.roundTripCodable(XCTUnwrap(UID.max)), try XCTUnwrap(UID.max))
    }
}

// MARK: - Strideable

extension UIDTests {
    func testAdvancedBy() {
        XCTAssertEqual(UID.max.advanced(by: 0), UID.max)
        XCTAssertEqual(UID.min.advanced(by: UID.min.distance(to: UID.max)), UID.max)
        XCTAssertEqual(UID.max.advanced(by: UID.max.distance(to: UID.min)), UID.min)
    }
}
