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

@Suite("MessageIdentifierSetNonEmpty<UID>")
struct UIDSetNonEmptyTests {}

extension UIDSetNonEmptyTests {
    @Test("init with set")
    func initWithSet() {
        #expect(
            MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>([6, 100...108]))?.set
                == MessageIdentifierSet<UID>([6, 100...108])
        )
    }

    @Test("init with range")
    func initWithRange() {
        #expect(
            MessageIdentifierSetNonEmpty(range: MessageIdentifierRange(100...108)).set
                == MessageIdentifierSet<UID>([100...108])
        )

        #expect(
            MessageIdentifierSetNonEmpty(range: MessageIdentifierRange(100)).set == MessageIdentifierSet<UID>([100])
        )
    }

    @Test("custom debug string convertible", arguments: [
        DebugStringFixture(
            sut: MessageIdentifierSetNonEmpty<UID>(set: [1])!,
            expected: "1"
        ),
        DebugStringFixture(
            sut: MessageIdentifierSetNonEmpty<UID>(set: [1...3, 6, 88])!,
            expected: "1:3,6,88"
        ),
        DebugStringFixture(
            sut: MessageIdentifierSetNonEmpty<UID>(set: [10, 20, 30])!,
            expected: "10,20,30"
        ),
        DebugStringFixture(
            sut: MessageIdentifierSetNonEmpty<UID>(set: [42...])!,
            expected: "42:*"
        ),
    ])
    func customDebugStringConvertible(_ fixture: DebugStringFixture<MessageIdentifierSetNonEmpty<UID>>) {
        fixture.check()
    }

    @Test(arguments: [
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [1])!,
            "1"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [1, 22...30, 47, 55, 66...])!,
            "1,22:30,47,55,66:*"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [1...3])!,
            "1:3"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [5, 10, 15])!,
            "5,10,15"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [100...200, 300...400, 500])!,
            "100:200,300:400,500"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [1, 3, 5...10, 20])!,
            "1,3,5:10,20"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [999...])!,
            "999:*"
        ),
        EncodeFixture.uidSet(
            MessageIdentifierSetNonEmpty<UID>(set: [1, 2, 3, 4, 5])!,
            "1:5"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessageIdentifierSetNonEmpty<UID>>) {
        fixture.checkEncoding()
    }

    @Test("min max")
    func minMax() {
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55])!.min() == 55)
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55])!.max() == 55)

        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55, 66])!.min() == 55)
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55, 66])!.max() == 66)

        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55...66])!.min() == 55)
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55...66])!.max() == 66)

        #expect(MessageIdentifierSetNonEmpty<UID>(set: [44, 55...66])!.min() == 44)
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [44, 55...66])!.max() == 66)

        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55...66, 77])!.min() == 55)
        #expect(MessageIdentifierSetNonEmpty<UID>(set: [55...66, 77])!.max() == 77)
    }
}

// MARK: -

extension EncodeFixture<MessageIdentifierSetNonEmpty<UID>> {
    fileprivate static func uidSet(
        _ input: MessageIdentifierSetNonEmpty<UID>,
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
