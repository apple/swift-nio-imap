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
import Testing

@Suite("UIDSet")
struct UIDSetTests {
    @Test(
        "custom debug string convertible",
        arguments: [
            DebugStringFixture(
                sut: [1...3, MessageIdentifierRange<UID>(6), MessageIdentifierRange<UID>(88)] as MessageIdentifierSet,
                expected: "1:3,6,88"
            ),
            DebugStringFixture(sut: [1...(UID.max)] as MessageIdentifierSet, expected: "1:*"),
            DebugStringFixture(sut: [MessageIdentifierRange<UID>(37)] as MessageIdentifierSet, expected: "37"),
            DebugStringFixture(sut: [MessageIdentifierRange<UID>(.max)] as MessageIdentifierSet, expected: "*"),
        ]
    )
    func customDebugStringConvertible(_ fixture: DebugStringFixture<MessageIdentifierSet<UID>>) {
        fixture.check()
    }

    @Test(arguments: [
        EncodeFixture.uidSet(MessageIdentifierSet<UID>(22...22), "22"),
        EncodeFixture.uidSet(MessageIdentifierSet<UID>(5...22), "5:22"),
        EncodeFixture.uidSet(MessageIdentifierSet<UID>.all, "1:*"),
        EncodeFixture.uidSet(MessageIdentifierSet<UID>(1...4_294_967_294), "1:4294967294"),
        EncodeFixture.uidSet(
            MessageIdentifierSet([
                MessageIdentifierRange<UID>(1),
                MessageIdentifierRange<UID>(22...30),
                MessageIdentifierRange<UID>(47),
                MessageIdentifierRange<UID>(55),
                MessageIdentifierRange<UID>(66...),
            ]),
            "1,22:30,47,55,66:*"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessageIdentifierSet<UID>>) {
        fixture.checkEncoding()
    }

    @Test("min max")
    func minMax() {
        #expect(MessageIdentifierSet<UID>().min() == nil)
        #expect(MessageIdentifierSet<UID>().max() == nil)

        #expect(MessageIdentifierSet<UID>([55]).min() == 55)
        #expect(MessageIdentifierSet<UID>([55]).max() == 55)

        #expect(MessageIdentifierSet<UID>([55, 66]).min() == 55)
        #expect(MessageIdentifierSet<UID>([55, 66]).max() == 66)

        #expect(MessageIdentifierSet<UID>([55...66]).min() == 55)
        #expect(MessageIdentifierSet<UID>([55...66]).max() == 66)

        #expect(MessageIdentifierSet<UID>([44, 55...66]).min() == 44)
        #expect(MessageIdentifierSet<UID>([44, 55...66]).max() == 66)

        #expect(MessageIdentifierSet<UID>([55...66, 77]).min() == 55)
        #expect(MessageIdentifierSet<UID>([55...66, 77]).max() == 77)
    }

    @Test func contains() {
        #expect(!MessageIdentifierSet<UID>(20...22).contains(19))
        #expect(MessageIdentifierSet<UID>(20...22).contains(20))
        #expect(MessageIdentifierSet<UID>(20...22).contains(21))
        #expect(MessageIdentifierSet<UID>(20...22).contains(22))
        #expect(!MessageIdentifierSet<UID>(20...22).contains(23))
        #expect(!MessageIdentifierSet<UID>(20...22).contains(.max))

        #expect(MessageIdentifierSet<UID>.all.contains(1))
        #expect(MessageIdentifierSet<UID>.all.contains(.max))
    }

    @Test func isContiguous() {
        #expect(MessageIdentifierSet<UID>.empty.isContiguous)
        #expect(MessageIdentifierSet<UID>(20 as UID).isContiguous)
        #expect(MessageIdentifierSet<UID>(20...22).isContiguous)
        #expect(!MessageIdentifierSet<UID>([20...22, 24...25]).isContiguous)
    }

    @Test func union() {
        #expect("\(MessageIdentifierSet<UID>(20 as UID).union(MessageIdentifierSet(30 as UID)))" == "20,30")
        #expect("\(MessageIdentifierSet<UID>(20 as UID).union(MessageIdentifierSet(21 as UID)))" == "20:21")
        #expect("\(MessageIdentifierSet<UID>(20 ... 22).union(MessageIdentifierSet(30 ... 39)))" == "20:22,30:39")
        #expect("\(MessageIdentifierSet<UID>(20 ... 35).union(MessageIdentifierSet(30 ... 39)))" == "20:39")
        #expect("\(MessageIdentifierSet<UID>(20 ... 35).union(MessageIdentifierSet(4 ... 39)))" == "4:39")
        #expect("\(MessageIdentifierSet<UID>(4 ... 39).union(MessageIdentifierSet(20 ... 35)))" == "4:39")
        #expect("\(MessageIdentifierSet<UID>.all.union(MessageIdentifierSet(20 ... 35)))" == "1:*")
        #expect("\(MessageIdentifierSet<UID>(20 ... 35).union(MessageIdentifierSet.all))" == "1:*")
        #expect(
            "\(MessageIdentifierSet<UID>(20 ... 21).union(MessageIdentifierSet(4_294_967_294 as UID)))"
                == "20:21,4294967294"
        )
    }

    @Test func intersection() {
        #expect("\(MessageIdentifierSet<UID>(20 as UID).intersection(MessageIdentifierSet(30 as UID)))" == "")
        #expect("\(MessageIdentifierSet<UID>(20 as UID).intersection(MessageIdentifierSet(20 as UID)))" == "20")
        #expect("\(MessageIdentifierSet<UID>(20 as UID).intersection(MessageIdentifierSet(18 ... 22)))" == "20")
        #expect("\(MessageIdentifierSet<UID>(20 ... 22).intersection(MessageIdentifierSet(30 ... 39)))" == "")
        #expect("\(MessageIdentifierSet<UID>(20 ... 35).intersection(MessageIdentifierSet(30 ... 39)))" == "30:35")
        #expect("\(MessageIdentifierSet<UID>.all.intersection(MessageIdentifierSet(20 ... 35)))" == "20:35")
        #expect("\(MessageIdentifierSet<UID>(20 ... 35).intersection(MessageIdentifierSet.all))" == "20:35")
        #expect(
            "\(MessageIdentifierSet<UID>.all.intersection(MessageIdentifierSet(2 ... 4_294_967_294)))"
                == "2:4294967294"
        )
    }

    @Test func symmetricDifference() {
        #expect(
            "\(MessageIdentifierSet<UID>(20 as UID).symmetricDifference(MessageIdentifierSet(30 as UID)))"
                == "20,30"
        )
        #expect(
            "\(MessageIdentifierSet<UID>(20 as UID).symmetricDifference(MessageIdentifierSet(20 as UID)))"
                == ""
        )
        #expect(
            "\(MessageIdentifierSet<UID>(20 ... 35).symmetricDifference(MessageIdentifierSet(30 ... 39)))"
                == "20:29,36:39"
        )
        #expect(
            "\(MessageIdentifierSet<UID>(20 ... 35).symmetricDifference(MessageIdentifierSet.all))"
                == "1:19,36:*"
        )
    }

    @Test func insert() {
        var sut = MessageIdentifierSet<UID>()
        #expect(sut.testInsert(4) == .inserted(4))
        #expect(sut.testInsert(6) == .inserted(6))
        #expect(sut.testInsert(5) == .inserted(5))
        #expect("\(sut)" == "4:6")
        #expect(sut.count == 3)
        #expect(sut.testInsert(6) == .existing(6))
        #expect(sut.testInsert(1) == .inserted(1))
        #expect("\(sut)" == "1,4:6")
        #expect(sut.count == 4)
    }

    @Test("remove 1")
    func remove1() {
        var sut = MessageIdentifierSet<UID>(4...6)
        #expect(sut.remove(1) == nil)
        #expect("\(sut)" == "4:6")
        #expect(sut.count == 3)
        #expect(sut.remove(5) == 5)
        #expect(sut.remove(5) == nil)
        #expect("\(sut)" == "4,6")
        #expect(sut.count == 2)
    }

    @Test("remove 2")
    func remove2() {
        var sut = MessageIdentifierSet<UID>(1...3)
        #expect(sut.remove(1) == 1)
        #expect("\(sut)" == "2:3")
        #expect(sut.count == 2)
    }

    @Test func update() {
        var sut = MessageIdentifierSet<UID>()
        #expect(sut.update(with: 4) == nil)
        #expect(sut.update(with: 6) == nil)
        #expect(sut.update(with: 5) == nil)
        #expect("\(sut)" == "4:6")
        #expect(sut.count == 3)
        #expect(sut.update(with: 6) == 6)
        #expect(sut.update(with: 1) == nil)
        #expect("\(sut)" == "1,4:6")
        #expect(sut.count == 4)
    }

    @Test func formUnion() {
        var sut = MessageIdentifierSet(20 as UID)
        sut.formUnion(MessageIdentifierSet(30 as UID))
        #expect("\(sut)" == "20,30")
    }

    @Test func formIntersection() {
        var sut = MessageIdentifierSet<UID>(20...35)
        sut.formIntersection(MessageIdentifierSet(30...40))
        #expect("\(sut)" == "30:35")
    }

    @Test func formSymmetricDifference() {
        var sut = MessageIdentifierSet<UID>(20...35)
        sut.formSymmetricDifference(MessageIdentifierSet(30...40))
        #expect("\(sut)" == "20:29,36:40")
    }

    @Test func subtracting() {
        let sut = MessageIdentifierSet<UID>(20...35)
        let a = sut.subtracting(MessageIdentifierSet<UID>(21...24))
        #expect("\(sut)" == "20:35")
        #expect("\(a)" == "20,25:35")
    }

    @Test func isSubset() {
        #expect(
            MessageIdentifierSet<UID>(20...35)
                .isSubset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isSubset(of: MessageIdentifierSet<UID>(2...3))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isSubset(of: MessageIdentifierSet<UID>(24...25))
        )
        #expect(
            !MessageIdentifierSet<UID>(2...3)
                .isSubset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            MessageIdentifierSet<UID>(24...25)
                .isSubset(of: MessageIdentifierSet<UID>(20...35))
        )
    }

    @Test func isStrictSubset() {
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isStrictSubset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isStrictSubset(of: MessageIdentifierSet<UID>(2...3))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isStrictSubset(of: MessageIdentifierSet<UID>(24...25))
        )
        #expect(
            !MessageIdentifierSet<UID>(2...3)
                .isStrictSubset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            MessageIdentifierSet<UID>(24...25)
                .isStrictSubset(of: MessageIdentifierSet<UID>(20...35))
        )
    }

    @Test func isDisjoint() {
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isDisjoint(with: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            MessageIdentifierSet<UID>(20...35)
                .isDisjoint(with: MessageIdentifierSet<UID>(2...3))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isDisjoint(with: MessageIdentifierSet<UID>(24...25))
        )
        #expect(
            MessageIdentifierSet<UID>(2...3)
                .isDisjoint(with: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(24...25)
                .isDisjoint(with: MessageIdentifierSet<UID>(20...35))
        )
    }

    @Test func isSuperset() {
        #expect(
            MessageIdentifierSet<UID>(20...35)
                .isSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isSuperset(of: MessageIdentifierSet<UID>(2...3))
        )
        #expect(
            MessageIdentifierSet<UID>(20...35)
                .isSuperset(of: MessageIdentifierSet<UID>(24...25))
        )
        #expect(
            !MessageIdentifierSet<UID>(2...3)
                .isSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(24...25)
                .isSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
    }

    @Test func isStrictSuperset() {
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isStrictSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(20...35)
                .isStrictSuperset(of: MessageIdentifierSet<UID>(2...3))
        )
        #expect(
            MessageIdentifierSet<UID>(20...35)
                .isStrictSuperset(of: MessageIdentifierSet<UID>(24...25))
        )
        #expect(
            !MessageIdentifierSet<UID>(2...3)
                .isStrictSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
        #expect(
            !MessageIdentifierSet<UID>(24...25)
                .isStrictSuperset(of: MessageIdentifierSet<UID>(20...35))
        )
    }

    @Test func subtract() {
        var sut = MessageIdentifierSet<UID>(20...35)
        sut.subtract(MessageIdentifierSet<UID>(21...24))
        #expect("\(sut)" == "20,25:35")
    }

    @Test func emptyCollection() {
        #expect(MessageIdentifierSet<UID>().map { "\($0)" } == [])
        #expect(MessageIdentifierSet<UID>().count == 0)
        #expect(MessageIdentifierSet<UID>().isEmpty)
    }

    @Test func singleElementCollection() {
        let sut = MessageIdentifierSet(55 as UID)
        #expect(sut.map { "\($0)" } == ["55"])
        #expect(sut.count == 1)
        #expect(!sut.isEmpty)
    }

    @Test func singleRangeCollection() {
        let sut = MessageIdentifierSet<UID>(55...57)
        #expect(sut.map { "\($0)" } == ["55", "56", "57"])
        #expect(sut.count == 3)
        #expect(!sut.isEmpty)
    }

    @Test("collection A")
    func collectionA() {
        let sut = MessageIdentifierSet([MessageIdentifierRange<UID>(55...57), MessageIdentifierRange<UID>(80)])
        #expect(sut.map { "\($0)" } == ["55", "56", "57", "80"])
        #expect(sut.count == 4)
        #expect(!sut.isEmpty)
    }

    @Test("collection B")
    func collectionB() {
        let sut = MessageIdentifierSet([MessageIdentifierRange<UID>(8), MessageIdentifierRange<UID>(55...57)])
        #expect(sut.map { "\($0)" } == ["8", "55", "56", "57"])
        #expect(sut.count == 4)
        #expect(!sut.isEmpty)
    }

    @Test("indexes single range")
    func indexesSingleRange() {
        let sut = MessageIdentifierSet<UID>(40...89)
        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6)
        )
        #expect(
            sut.index(sut.index(sut.startIndex, offsetBy: 33), offsetBy: -33)
                == sut.startIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 50)
                == sut.endIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -50)
                == sut.startIndex
        )

        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100)
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110)
        )

        #expect(
            sut.index(sut.startIndex, offsetBy: 51)
                > sut.endIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 52)
                > sut.index(sut.startIndex, offsetBy: 51)
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -51)
                < sut.startIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -52)
                < sut.index(sut.endIndex, offsetBy: -51)
        )

        #expect(sut.index(sut.endIndex, offsetBy: -50, limitedBy: sut.startIndex) == sut.startIndex)
        #expect(sut.index(sut.endIndex, offsetBy: -51, limitedBy: sut.startIndex) == nil)

        #expect(sut.index(sut.startIndex, offsetBy: 50, limitedBy: sut.endIndex) == sut.endIndex)
        #expect(sut.index(sut.startIndex, offsetBy: 51, limitedBy: sut.endIndex) == nil)
    }

    @Test("indexes multiple single values")
    func indexesMultipleSingleValues() {
        let sut: MessageIdentifierSet<UID> = {
            var sut = MessageIdentifierSet<UID>()
            for uid in [
                762 as UID, 7370, 8568, 11423, 11708, 11889, 12679,
                18833, 22152, 22374, 22733, 23838, 30058, 30985, 32465,
                33579, 39714, 43224, 44377, 46424, 53884, 61461, 71310,
                75310, 77045, 81983, 82711, 85170, 95660, 99173,
            ] {
                sut.insert(uid)
            }
            return sut
        }()
        #expect(sut.count == 30)

        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6)
        )
        #expect(
            sut.index(sut.index(sut.startIndex, offsetBy: 17), offsetBy: -17)
                == sut.startIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 30)
                == sut.endIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -30)
                == sut.startIndex
        )

        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100)
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110)
        )

        #expect(
            sut.index(sut.startIndex, offsetBy: 31)
                > sut.endIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 32)
                > sut.index(sut.startIndex, offsetBy: 31)
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -31)
                < sut.startIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -32)
                < sut.index(sut.endIndex, offsetBy: -31)
        )

        #expect(sut.index(sut.endIndex, offsetBy: -30, limitedBy: sut.startIndex) == sut.startIndex)
        #expect(sut.index(sut.endIndex, offsetBy: -31, limitedBy: sut.startIndex) == nil)

        #expect(sut.index(sut.startIndex, offsetBy: 30, limitedBy: sut.endIndex) == sut.endIndex)
        #expect(sut.index(sut.startIndex, offsetBy: 31, limitedBy: sut.endIndex) == nil)
    }

    @Test("indexes multiple short ranges")
    func indexesMultipleShortRanges() {
        let sut = MessageIdentifierSet([
            MessageIdentifierRange<UID>(55...57),
            MessageIdentifierRange<UID>(155...157),
            MessageIdentifierRange<UID>(255...257),
            MessageIdentifierRange<UID>(355...357),
            MessageIdentifierRange<UID>(455...457),
            MessageIdentifierRange<UID>(555...557),
            MessageIdentifierRange<UID>(655...657),
            MessageIdentifierRange<UID>(755...757),
            MessageIdentifierRange<UID>(855...857),
            MessageIdentifierRange<UID>(955...957),
        ])
        #expect(sut.count == 30)

        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 4), offsetBy: 6)
        )
        #expect(
            sut.index(sut.index(sut.startIndex, offsetBy: 17), offsetBy: -17)
                == sut.startIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 30)
                == sut.endIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -30)
                == sut.startIndex
        )

        for step in 1...15 {
            let count = sut.count / step
            var a = sut.startIndex
            for c in 1...count {
                a = sut.index(a, offsetBy: step)
                #expect(
                    a == sut.index(sut.startIndex, offsetBy: step * c),
                    Comment("c = \(c), step = \(step)")
                )
                #expect(
                    sut.distance(from: sut.startIndex, to: a) == step * c,
                    Comment("c = \(c), step = \(step)")
                )
                #expect(
                    sut.distance(from: sut.endIndex, to: a) == step * c - 30,
                    Comment("c = \(c), step = \(step)")
                )
            }
        }

        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: 110), offsetBy: -100)
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 10)
                == sut.index(sut.index(sut.startIndex, offsetBy: -100), offsetBy: 110)
        )

        #expect(
            sut.index(sut.startIndex, offsetBy: 31)
                > sut.endIndex
        )
        #expect(
            sut.index(sut.startIndex, offsetBy: 32)
                > sut.index(sut.startIndex, offsetBy: 31)
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -31)
                < sut.startIndex
        )
        #expect(
            sut.index(sut.endIndex, offsetBy: -32)
                < sut.index(sut.endIndex, offsetBy: -31)
        )

        #expect(sut.index(sut.endIndex, offsetBy: -30, limitedBy: sut.startIndex) == sut.startIndex)
        #expect(sut.index(sut.endIndex, offsetBy: -31, limitedBy: sut.startIndex) == nil)

        #expect(sut.index(sut.startIndex, offsetBy: 30, limitedBy: sut.endIndex) == sut.endIndex)
        #expect(sut.index(sut.startIndex, offsetBy: 31, limitedBy: sut.endIndex) == nil)
    }

    @Test func rangeView() {
        #expect(Array(MessageIdentifierSet<UID>().ranges) == [])
        #expect(
            Array(MessageIdentifierSet<UID>([1_234]).ranges)
                == [
                    MessageIdentifierRange<UID>(1_234...1_234)
                ]
        )
        #expect(
            Array(MessageIdentifierSet([1, 4]).ranges)
                == [
                    MessageIdentifierRange<UID>(1...1),
                    MessageIdentifierRange<UID>(4...4),
                ]
        )
        #expect(
            Array(
                MessageIdentifierSet([
                    17...32,
                    400...1_234,
                    2_001...2_001,
                    20_800...21_044,
                ]).ranges
            )
                == [
                    MessageIdentifierRange<UID>(17...32),
                    MessageIdentifierRange<UID>(400...1_234),
                    MessageIdentifierRange<UID>(2_001...2_001),
                    MessageIdentifierRange<UID>(20_800...21_044),
                ]
        )
    }
}

// MARK: -

extension EncodeFixture<MessageIdentifierSet<UID>> {
    fileprivate static func uidSet(
        _ input: MessageIdentifierSet<UID>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUIDSet($1) }
        )
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
