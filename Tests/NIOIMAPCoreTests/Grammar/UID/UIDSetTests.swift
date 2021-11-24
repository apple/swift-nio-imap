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

class UIDSetTests: EncodeTestClass {}

// MARK: - CustomDebugStringConvertible

extension UIDSetTests {
    func testCustomDebugStringConvertible() {
        XCTAssertEqual("\([1 ... 3, MessageIdentifierRange<UID>(6), MessageIdentifierRange<UID>(88)] as MessageIdentifierSet)", "1:3,6,88")
        XCTAssertEqual("\([1 ... (.max)] as MessageIdentifierSet)", "1:*")
        XCTAssertEqual("\([MessageIdentifierRange<UID>(37)] as MessageIdentifierSet)", "37")
        XCTAssertEqual("\([MessageIdentifierRange<UID>(.max)] as MessageIdentifierSet)", "*")
    }
}

// MARK: - Encoding

extension UIDSetTests {
    func testIMAPEncoded_one() {
        let expected = "22"
        let size = self.testBuffer.writeUIDSet(MessageIdentifierSet(22 ... 22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_oneRange() {
        let expected = "5:22"
        let size = self.testBuffer.writeUIDSet(MessageIdentifierSet(5 ... 22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_all() {
        let expected = "1:*"
        let size = self.testBuffer.writeUIDSet(MessageIdentifierSet<UID>.all)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_almostAll() {
        let expected = "1:4294967294"
        let size = self.testBuffer.writeUIDSet(MessageIdentifierSet(1 ... 4_294_967_294))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_full() {
        let expected = "1,22:30,47,55,66:*"
        let size = self.testBuffer.writeUIDSet(MessageIdentifierSet([
            MessageIdentifierRange<UID>(1),
            MessageIdentifierRange<UID>(22 ... 30),
            MessageIdentifierRange<UID>(47),
            MessageIdentifierRange<UID>(55),
            MessageIdentifierRange<UID>(66...),
        ]))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Set Algebra

extension UIDSetTests {
    func testContains() {
        XCTAssertFalse(MessageIdentifierSet(20 ... 22).contains(19))
        XCTAssert(MessageIdentifierSet(20 ... 22).contains(20))
        XCTAssert(MessageIdentifierSet(20 ... 22).contains(21))
        XCTAssert(MessageIdentifierSet(20 ... 22).contains(22))
        XCTAssertFalse(MessageIdentifierSet(20 ... 22).contains(23))
        XCTAssertFalse(MessageIdentifierSet(20 ... 22).contains(.max))

        XCTAssert(MessageIdentifierSet<UID>.all.contains(1))
        XCTAssert(MessageIdentifierSet<UID>.all.contains(.max))
    }

    func testUnion() {
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).union(MessageIdentifierSet(30 as UID)))", "20,30")
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).union(MessageIdentifierSet(21 as UID)))", "20:21")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 22).union(MessageIdentifierSet(30 ... 39)))", "20:22,30:39")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).union(MessageIdentifierSet(30 ... 39)))", "20:39")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).union(MessageIdentifierSet(4 ... 39)))", "4:39")
        XCTAssertEqual("\(MessageIdentifierSet(4 ... 39).union(MessageIdentifierSet(20 ... 35)))", "4:39")
        XCTAssertEqual("\(MessageIdentifierSet.all.union(MessageIdentifierSet(20 ... 35)))", "1:*")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).union(MessageIdentifierSet.all))", "1:*")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 21).union(MessageIdentifierSet(4_294_967_294 as UID)))", "20:21,4294967294")
    }

    func testIntersection() {
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).intersection(MessageIdentifierSet(30 as UID)))", "")
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).intersection(MessageIdentifierSet(20 as UID)))", "20")
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).intersection(MessageIdentifierSet(18 ... 22)))", "20")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 22).intersection(MessageIdentifierSet(30 ... 39)))", "")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).intersection(MessageIdentifierSet(30 ... 39)))", "30:35")
        XCTAssertEqual("\(MessageIdentifierSet.all.intersection(MessageIdentifierSet(20 ... 35)))", "20:35")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).intersection(MessageIdentifierSet.all))", "20:35")
        XCTAssertEqual("\(MessageIdentifierSet.all.intersection(MessageIdentifierSet(2 ... 4_294_967_294)))", "2:4294967294")
    }

    func testSymmetricDifference() {
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).symmetricDifference(MessageIdentifierSet(30 as UID)))", "20,30")
        XCTAssertEqual("\(MessageIdentifierSet(20 as UID).symmetricDifference(MessageIdentifierSet(20 as UID)))", "")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).symmetricDifference(MessageIdentifierSet(30 ... 39)))", "20:29,36:39")
        XCTAssertEqual("\(MessageIdentifierSet(20 ... 35).symmetricDifference(MessageIdentifierSet.all))", "1:19,36:*")
    }

    func testInsert() {
        var sut = MessageIdentifierSet<UID>()
        XCTAssertEqual(sut.testInsert(4), .inserted(4))
        XCTAssertEqual(sut.testInsert(6), .inserted(6))
        XCTAssertEqual(sut.testInsert(5), .inserted(5))
        XCTAssertEqual("\(sut)", "4:6")
        XCTAssertEqual(sut.count, 3)
        XCTAssertEqual(sut.testInsert(6), .existing(6))
        XCTAssertEqual(sut.testInsert(1), .inserted(1))
        XCTAssertEqual("\(sut)", "1,4:6")
        XCTAssertEqual(sut.count, 4)
    }

    func testRemove_1() {
        var sut = MessageIdentifierSet(4 ... 6)
        XCTAssertNil(sut.remove(1))
        XCTAssertEqual("\(sut)", "4:6")
        XCTAssertEqual(sut.count, 3)
        XCTAssertEqual(sut.remove(5), 5)
        XCTAssertNil(sut.remove(5))
        XCTAssertEqual("\(sut)", "4,6")
        XCTAssertEqual(sut.count, 2)
    }

    func testRemove_2() {
        var sut = MessageIdentifierSet(1 ... 3)
        XCTAssertEqual(sut.remove(1), 1)
        XCTAssertEqual("\(sut)", "2:3")
        XCTAssertEqual(sut.count, 2)
    }

    func testUpdate() {
        var sut = MessageIdentifierSet<UID>()
        XCTAssertEqual(sut.update(with: 4), nil)
        XCTAssertEqual(sut.update(with: 6), nil)
        XCTAssertEqual(sut.update(with: 5), nil)
        XCTAssertEqual("\(sut)", "4:6")
        XCTAssertEqual(sut.count, 3)
        XCTAssertEqual(sut.update(with: 6), 6)
        XCTAssertEqual(sut.update(with: 1), nil)
        XCTAssertEqual("\(sut)", "1,4:6")
        XCTAssertEqual(sut.count, 4)
    }

    func testFormUnion() {
        var sut = MessageIdentifierSet(20 as UID)
        sut.formUnion(MessageIdentifierSet(30 as UID))
        XCTAssertEqual("\(sut)", "20,30")
    }

    func testFormIntersection() {
        var sut = MessageIdentifierSet(20 ... 35)
        sut.formIntersection(MessageIdentifierSet(30 ... 40))
        XCTAssertEqual("\(sut)", "30:35")
    }

    func testFormSymmetricDifference() {
        var sut = MessageIdentifierSet(20 ... 35)
        sut.formSymmetricDifference(MessageIdentifierSet(30 ... 40))
        XCTAssertEqual("\(sut)", "20:29,36:40")
    }

    func testEmptyCollection() {
        XCTAssertEqual(MessageIdentifierSet<UID>().map { "\($0)" }, [])
        XCTAssertEqual(MessageIdentifierSet<UID>().count, 0)
        XCTAssert(MessageIdentifierSet<UID>().isEmpty)
    }

    func testSingleElementCollection() {
        let sut = MessageIdentifierSet(55 as UID)
        XCTAssertEqual(sut.map { "\($0)" }, ["55"])
        XCTAssertEqual(sut.count, 1)
        XCTAssertFalse(sut.isEmpty)
    }

    func testSingleRangeCollection() {
        let sut = MessageIdentifierSet(55 ... 57)
        XCTAssertEqual(sut.map { "\($0)" }, ["55", "56", "57"])
        XCTAssertEqual(sut.count, 3)
        XCTAssertFalse(sut.isEmpty)
    }

    func testCollection_A() {
        let sut = MessageIdentifierSet([MessageIdentifierRange<UID>(55 ... 57), MessageIdentifierRange<UID>(80)])
        XCTAssertEqual(sut.map { "\($0)" }, ["55", "56", "57", "80"])
        XCTAssertEqual(sut.count, 4)
        XCTAssertFalse(sut.isEmpty)
    }

    func testCollection_B() {
        let sut = MessageIdentifierSet([MessageIdentifierRange<UID>(8), MessageIdentifierRange<UID>(55 ... 57)])
        XCTAssertEqual(sut.map { "\($0)" }, ["8", "55", "56", "57"])
        XCTAssertEqual(sut.count, 4)
        XCTAssertFalse(sut.isEmpty)
    }
}

extension UIDSetTests {
    func testIndexes_singleRange() {
        let sut = MessageIdentifierSet(40 ... 89)
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6))
        XCTAssertEqual(sut.index(sut.index(sut.startIndex, offsetBy: 33), offsetBy: -33),
                       sut.startIndex)
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 50),
                       sut.endIndex)
        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -50),
                       sut.startIndex)

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100))
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110))

        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 51),
                             sut.endIndex)
        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 52),
                             sut.index(sut.startIndex, offsetBy: 51))
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -51),
                          sut.startIndex)
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -52),
                          sut.index(sut.endIndex, offsetBy: -51))

        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -50, limitedBy: sut.startIndex), sut.startIndex)
        XCTAssertNil(sut.index(sut.endIndex, offsetBy: -51, limitedBy: sut.startIndex))

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 50, limitedBy: sut.endIndex), sut.endIndex)
        XCTAssertNil(sut.index(sut.startIndex, offsetBy: 51, limitedBy: sut.endIndex))
    }

    func testIndexes_multipleSingleValues() {
        let sut: MessageIdentifierSet<UID> = {
            var sut = MessageIdentifierSet<UID>()
            for uid in [762 as UID, 7370, 8568, 11423, 11708, 11889, 12679,
                        18833, 22152, 22374, 22733, 23838, 30058, 30985, 32465,
                        33579, 39714, 43224, 44377, 46424, 53884, 61461, 71310,
                        75310, 77045, 81983, 82711, 85170, 95660, 99173]
            {
                sut.insert(uid)
            }
            return sut
        }()
        XCTAssertEqual(sut.count, 30, "30 values")

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6))
        XCTAssertEqual(sut.index(sut.index(sut.startIndex, offsetBy: 17), offsetBy: -17),
                       sut.startIndex)
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 30),
                       sut.endIndex)
        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -30),
                       sut.startIndex)

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100))
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110))

        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 31),
                             sut.endIndex)
        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 32),
                             sut.index(sut.startIndex, offsetBy: 31))
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -31),
                          sut.startIndex)
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -32),
                          sut.index(sut.endIndex, offsetBy: -31))

        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -30, limitedBy: sut.startIndex), sut.startIndex)
        XCTAssertNil(sut.index(sut.endIndex, offsetBy: -31, limitedBy: sut.startIndex))

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 30, limitedBy: sut.endIndex), sut.endIndex)
        XCTAssertNil(sut.index(sut.startIndex, offsetBy: 31, limitedBy: sut.endIndex))
    }

    func testIndexes_multipleShortRanges() {
        let sut = MessageIdentifierSet([
            MessageIdentifierRange<UID>(55 ... 57),
            MessageIdentifierRange<UID>(155 ... 157),
            MessageIdentifierRange<UID>(255 ... 257),
            MessageIdentifierRange<UID>(355 ... 357),
            MessageIdentifierRange<UID>(455 ... 457),
            MessageIdentifierRange<UID>(555 ... 557),
            MessageIdentifierRange<UID>(655 ... 657),
            MessageIdentifierRange<UID>(755 ... 757),
            MessageIdentifierRange<UID>(855 ... 857),
            MessageIdentifierRange<UID>(955 ... 957),
        ])
        XCTAssertEqual(sut.count, 30, "30 values")

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6))
        XCTAssertEqual(sut.index(sut.index(sut.startIndex, offsetBy: 17), offsetBy: -17),
                       sut.startIndex)
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 30),
                       sut.endIndex)
        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -30),
                       sut.startIndex)

        for step in 1 ... 15 {
            let count = sut.count / step
            var a = sut.startIndex
            for c in 1 ... count {
                a = sut.index(a, offsetBy: step)
                XCTAssertEqual(a,
                               sut.index(sut.startIndex, offsetBy: step * c),
                               "c = \(c), step = \(step)")
                XCTAssertEqual(sut.distance(from: sut.startIndex, to: a),
                               step * c,
                               "c = \(c), step = \(step)")
                XCTAssertEqual(sut.distance(from: sut.endIndex, to: a),
                               step * c - 30,
                               "c = \(c), step = \(step)")
            }
        }

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100))
        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 10),
                       sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110))

        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 31),
                             sut.endIndex)
        XCTAssertGreaterThan(sut.index(sut.startIndex, offsetBy: 32),
                             sut.index(sut.startIndex, offsetBy: 31))
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -31),
                          sut.startIndex)
        XCTAssertLessThan(sut.index(sut.endIndex, offsetBy: -32),
                          sut.index(sut.endIndex, offsetBy: -31))

        XCTAssertEqual(sut.index(sut.endIndex, offsetBy: -30, limitedBy: sut.startIndex), sut.startIndex)
        XCTAssertNil(sut.index(sut.endIndex, offsetBy: -31, limitedBy: sut.startIndex))

        XCTAssertEqual(sut.index(sut.startIndex, offsetBy: 30, limitedBy: sut.endIndex), sut.endIndex)
        XCTAssertNil(sut.index(sut.startIndex, offsetBy: 31, limitedBy: sut.endIndex))
    }

    func testRangeView() {
        XCTAssertEqual(Array(MessageIdentifierSet<UID>().ranges), [])
        XCTAssertEqual(Array(MessageIdentifierSet<UID>([1_234]).ranges), [
            MessageIdentifierRange<UID>(1_234 ... 1_234),
        ])
        XCTAssertEqual(Array(MessageIdentifierSet([1, 4]).ranges), [
            MessageIdentifierRange<UID>(1 ... 1),
            MessageIdentifierRange<UID>(4 ... 4),
        ])
        XCTAssertEqual(Array(MessageIdentifierSet([
            17 ... 32,
            400 ... 1_234,
            2_001 ... 2_001,
            20_800 ... 21_044,
        ]).ranges), [
            MessageIdentifierRange<UID>(17 ... 32),
            MessageIdentifierRange<UID>(400 ... 1_234),
            MessageIdentifierRange<UID>(2_001 ... 2_001),
            MessageIdentifierRange<UID>(20_800 ... 21_044),
        ])
    }
}

/// Helper to make the result equatable
private enum InsertResult: Equatable {
    case inserted(UID)
    case existing(UID)
}

extension SetAlgebra where Element == UID {
    fileprivate mutating func testInsert(_ newMember: UID) -> InsertResult {
        let r = insert(newMember)
        return r.0 ? .inserted(r.1) : .existing(r.1)
    }
}
