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

class UIDSetNonEmptyTests: EncodeTestClass {}

// MARK: - init

extension UIDSetNonEmptyTests {
    func testInitWithSet() {
        XCTAssertEqual(
            MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>([6, 100...108]))?.set,
            MessageIdentifierSet<UID>([6, 100...108])
        )
    }

    func testInitWithRange() {
        XCTAssertEqual(
            MessageIdentifierSetNonEmpty(range: MessageIdentifierRange(100...108)).set,
            MessageIdentifierSet<UID>([100...108])
        )

        XCTAssertEqual(
            MessageIdentifierSetNonEmpty(range: MessageIdentifierRange(100)).set,
            MessageIdentifierSet<UID>([100])
        )
    }
}

// MARK: - CustomDebugStringConvertible

extension UIDSetNonEmptyTests {
    func testCustomDebugStringConvertible() {
        XCTAssertEqual("\(MessageIdentifierSetNonEmpty<UID>(set: [1 ... 3, 6, 88])!)", "1:3,6,88")
    }
}

// MARK: - Encoding

extension UIDSetNonEmptyTests {
    func testIMAPEncoded_full() {
        let expected = "1,22:30,47,55,66:*"
        let size = self.testBuffer.writeUIDSet(
            MessageIdentifierSetNonEmpty<UID>(set: [
                1,
                22...30,
                47,
                55,
                66...,
            ])!
        )
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Min Max

extension UIDSetNonEmptyTests {
    func testMinMax() {
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55])!.min(), 55)
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55])!.max(), 55)

        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55, 66])!.min(), 55)
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55, 66])!.max(), 66)

        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55...66])!.min(), 55)
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55...66])!.max(), 66)

        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [44, 55...66])!.min(), 44)
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [44, 55...66])!.max(), 66)

        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55...66, 77])!.min(), 55)
        XCTAssertEqual(MessageIdentifierSetNonEmpty<UID>(set: [55...66, 77])!.max(), 77)
    }
}
