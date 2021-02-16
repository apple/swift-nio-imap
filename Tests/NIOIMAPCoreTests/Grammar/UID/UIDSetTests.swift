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

class UIDSetTests: EncodeTestClass {}

// MARK: - CustomDebugStringConvertible

extension UIDSetTests {
    func testCustomDebugStringConvertible() {
        XCTAssertEqual("\([1 ... 3, UIDRange(6), UIDRange(88)] as UIDSet)", "1:3,6,88")
        XCTAssertEqual("\([1 ... (.max)] as UIDSet)", "1:*")
        XCTAssertEqual("\([UIDRange(37)] as UIDSet)", "37")
        XCTAssertEqual("\([UIDRange(.max)] as UIDSet)", "*")
    }
}

// MARK: - Encoding

extension UIDSetTests {
    func testIMAPEncoded_one() {
        let expected = "22"
        let size = self.testBuffer.writeUIDSet(UIDSet(22 ... 22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_oneRange() {
        let expected = "5:22"
        let size = self.testBuffer.writeUIDSet(UIDSet(5 ... 22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_all() {
        let expected = "1:*"
        let size = self.testBuffer.writeUIDSet(.all)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_almostAll() {
        let expected = "1:4294967294"
        let size = self.testBuffer.writeUIDSet(UIDSet(1 ... 4_294_967_294))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_full() {
        let expected = "1,22:30,47,55,66:*"
        let size = self.testBuffer.writeUIDSet(UIDSet([
            UIDRange(1),
            UIDRange(22 ... 30),
            UIDRange(47),
            UIDRange(55),
            UIDRange(66...),
        ]))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Set Algebra

extension UIDSetTests {
    func testContains() {
        XCTAssertFalse(UIDSet(20 ... 22).contains(19))
        XCTAssert(UIDSet(20 ... 22).contains(20))
        XCTAssert(UIDSet(20 ... 22).contains(21))
        XCTAssert(UIDSet(20 ... 22).contains(22))
        XCTAssertFalse(UIDSet(20 ... 22).contains(23))
        XCTAssertFalse(UIDSet(20 ... 22).contains(.max))

        XCTAssert(UIDSet.all.contains(1))
        XCTAssert(UIDSet.all.contains(.max))
    }

    func testUnion() {
        XCTAssertEqual("\(UIDSet(20 as UID).union(UIDSet(30 as UID)))", "20,30")
        XCTAssertEqual("\(UIDSet(20 as UID).union(UIDSet(21 as UID)))", "20:21")
        XCTAssertEqual("\(UIDSet(20 ... 22).union(UIDSet(30 ... 39)))", "20:22,30:39")
        XCTAssertEqual("\(UIDSet(20 ... 35).union(UIDSet(30 ... 39)))", "20:39")
        XCTAssertEqual("\(UIDSet(20 ... 35).union(UIDSet(4 ... 39)))", "4:39")
        XCTAssertEqual("\(UIDSet(4 ... 39).union(UIDSet(20 ... 35)))", "4:39")
        XCTAssertEqual("\(UIDSet.all.union(UIDSet(20 ... 35)))", "1:*")
        XCTAssertEqual("\(UIDSet(20 ... 35).union(UIDSet.all))", "1:*")
        XCTAssertEqual("\(UIDSet(20 ... 21).union(UIDSet(4_294_967_294 as UID)))", "20:21,4294967294")
    }

    func testIntersection() {
        XCTAssertEqual("\(UIDSet(20 as UID).intersection(UIDSet(30 as UID)))", "")
        XCTAssertEqual("\(UIDSet(20 as UID).intersection(UIDSet(20 as UID)))", "20")
        XCTAssertEqual("\(UIDSet(20 as UID).intersection(UIDSet(18 ... 22)))", "20")
        XCTAssertEqual("\(UIDSet(20 ... 22).intersection(UIDSet(30 ... 39)))", "")
        XCTAssertEqual("\(UIDSet(20 ... 35).intersection(UIDSet(30 ... 39)))", "30:35")
        XCTAssertEqual("\(UIDSet.all.intersection(UIDSet(20 ... 35)))", "20:35")
        XCTAssertEqual("\(UIDSet(20 ... 35).intersection(UIDSet.all))", "20:35")
        XCTAssertEqual("\(UIDSet.all.intersection(UIDSet(2 ... 4_294_967_294)))", "2:4294967294")
    }

    func testSymmetricDifference() {
        XCTAssertEqual("\(UIDSet(20 as UID).symmetricDifference(UIDSet(30 as UID)))", "20,30")
        XCTAssertEqual("\(UIDSet(20 as UID).symmetricDifference(UIDSet(20 as UID)))", "")
        XCTAssertEqual("\(UIDSet(20 ... 35).symmetricDifference(UIDSet(30 ... 39)))", "20:29,36:39")
        XCTAssertEqual("\(UIDSet(20 ... 35).symmetricDifference(UIDSet.all))", "1:19,36:*")
    }

    func testInsert() {
        var sut = UIDSet()
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
        var sut = UIDSet(4 ... 6)
        XCTAssertNil(sut.remove(1))
        XCTAssertEqual("\(sut)", "4:6")
        XCTAssertEqual(sut.count, 3)
        XCTAssertEqual(sut.remove(5), 5)
        XCTAssertNil(sut.remove(5))
        XCTAssertEqual("\(sut)", "4,6")
        XCTAssertEqual(sut.count, 2)
    }

    func testRemove_2() {
        var sut = UIDSet(1 ... 3)
        XCTAssertEqual(sut.remove(1), 1)
        XCTAssertEqual("\(sut)", "2:3")
        XCTAssertEqual(sut.count, 2)
    }

    func testUpdate() {
        var sut = UIDSet()
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
        var sut = UIDSet(20 as UID)
        sut.formUnion(UIDSet(30 as UID))
        XCTAssertEqual("\(sut)", "20,30")
    }

    func testFormIntersection() {
        var sut = UIDSet(20 ... 35)
        sut.formIntersection(UIDSet(30 ... 40))
        XCTAssertEqual("\(sut)", "30:35")
    }

    func testFormSymmetricDifference() {
        var sut = UIDSet(20 ... 35)
        sut.formSymmetricDifference(UIDSet(30 ... 40))
        XCTAssertEqual("\(sut)", "20:29,36:40")
    }

    func testEmptyCollection() {
        XCTAssertEqual(UIDSet().map { "\($0)" }, [])
        XCTAssertEqual(UIDSet().count, 0)
        XCTAssert(UIDSet().isEmpty)
    }

    func testSingleElementCollection() {
        let sut = UIDSet(55 as UID)
        XCTAssertEqual(sut.map { "\($0)" }, ["55"])
        XCTAssertEqual(sut.count, 1)
        XCTAssertFalse(sut.isEmpty)
    }

    func testSingleRangeCollection() {
        let sut = UIDSet(55 ... 57)
        XCTAssertEqual(sut.map { "\($0)" }, ["55", "56", "57"])
        XCTAssertEqual(sut.count, 3)
        XCTAssertFalse(sut.isEmpty)
    }

    func testCollection_A() {
        let sut = UIDSet([UIDRange(55 ... 57), UIDRange(80)])
        XCTAssertEqual(sut.map { "\($0)" }, ["55", "56", "57", "80"])
        XCTAssertEqual(sut.count, 4)
        XCTAssertFalse(sut.isEmpty)
    }

    func testCollection_B() {
        let sut = UIDSet([UIDRange(8), UIDRange(55 ... 57)])
        XCTAssertEqual(sut.map { "\($0)" }, ["8", "55", "56", "57"])
        XCTAssertEqual(sut.count, 4)
        XCTAssertFalse(sut.isEmpty)
    }
}

extension UIDSetTests {
    func testIndexes_singleRange() {
        let sut = UIDSet(40 ... 89)
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
        let sut: UIDSet = {
            var sut = UIDSet()
            for uid in [762 as UID, 7370, 8568, 11423, 11708, 11889, 12679,
                        18833, 22152, 22374, 22733, 23838, 30058, 30985, 32465,
                        33579, 39714, 43224, 44377, 46424, 53884, 61461, 71310,
                        75310, 77045, 81983, 82711, 85170, 95660, 99173] {
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
        let sut = UIDSet([
            UIDRange(55 ... 57),
            UIDRange(155 ... 157),
            UIDRange(255 ... 257),
            UIDRange(355 ... 357),
            UIDRange(455 ... 457),
            UIDRange(555 ... 557),
            UIDRange(655 ... 657),
            UIDRange(755 ... 757),
            UIDRange(855 ... 857),
            UIDRange(955 ... 957),
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
        XCTAssertEqual(Array(UIDSet().ranges), [])
        XCTAssertEqual(Array(UIDSet([1_234]).ranges), [
            UIDRange(1_234 ... 1_234),
        ])
        XCTAssertEqual(Array(UIDSet([1, 4]).ranges), [
            UIDRange(1 ... 1),
            UIDRange(4 ... 4),
        ])
        XCTAssertEqual(Array(UIDSet([17 ... 32, 400 ... 1_234, 2_001, 20_800 ... 21_044]).ranges), [
            UIDRange(17 ... 32),
            UIDRange(400 ... 1_234),
            UIDRange(2_001),
            UIDRange(20_800 ... 21_044),
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
