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
import SwiftCheck
import XCTest

class SequenceNumberTests: EncodeTestClass {}

// MARK: - Integer literal

extension SequenceNumberTests {
    func testIntegerLiteral() {
        let num: SequenceNumber = 5
        XCTAssertEqual(num, 5)
    }
}

// MARK: - Comparable

extension SequenceNumberTests {
    func testComparable() {
        XCTAssertFalse(SequenceNumber.max < .max)
        XCTAssertFalse(SequenceNumber.max < 999)
        XCTAssertTrue(SequenceNumber.max > 999)
        XCTAssertTrue(SequenceNumber(1) < 999) // use .number to force type
    }
}

// MARK: - Encoding

extension SequenceNumberTests {
    func testEncode_max() {
        let expected = "4294967295"
        let size = self.testBuffer.writeSequenceNumber(.max)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testEncode_number() {
        let expected = "1234"
        let size = self.testBuffer.writeSequenceNumber(1234)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Round Trip

extension SequenceNumber: Arbitrary {
    public static var arbitrary: Gen<SequenceNumber> {
        Gen<Int>
            .choose((SequenceNumber.min.rawValue, SequenceNumber.max.rawValue))
            .map { SequenceNumber($0) }
    }

    public static func shrink(_ seq: SequenceNumber) -> [SequenceNumber] {
        guard seq != SequenceNumber.min else { return [] }
        return [SequenceNumber.min]
    }
}

extension SequenceNumberTests {
    func testRoundTrip_encodeDecode() {
        let suffixGen = Gen.fromElements(of: [" ", ")"])
        property("round-trips") <- forAll(SequenceNumber.arbitrary, suffixGen) { (seq: SequenceNumber, suffix: String) throws in
            let decoded = try self.roundTrip(value: seq, suffix: suffix, encode: {
                $0.writeSequenceNumber($1)
            }, decode: {
                let s = try GrammarParser.parseSequenceNumber(buffer: &$0, tracker: .testTracker)
                return s
            })
            return decoded == seq
        }
    }
}
