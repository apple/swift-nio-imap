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

class MessageIdentifierSet_Tests: EncodeTestClass {}

// MARK: - Conversion

extension MessageIdentifierSet_Tests {
    func testConvert_sequenceNumber() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<SequenceNumber>(input)
        XCTAssertEqual(output, [1...5, 10...15, 20...30])
    }

    func testConvert_uid() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<UID>(input)
        XCTAssertEqual(output, [1...5, 10...15, 20...30])
    }

    func testSuffix() {
        XCTAssertEqual(UIDSet().suffix(0), UIDSet())
        XCTAssertEqual(UIDSet([1]).suffix(0), UIDSet())
        XCTAssertEqual(UIDSet([100, 200]).suffix(0), UIDSet())

        XCTAssertEqual(UIDSet([100, 200]).suffix(1), UIDSet([200]))
        XCTAssertEqual(UIDSet([100, 200]).suffix(2), UIDSet([100, 200]))
        XCTAssertEqual(UIDSet([100, 200]).suffix(3), UIDSet([100, 200]))

        XCTAssertEqual(UIDSet([200...299]).suffix(0), UIDSet())
        XCTAssertEqual(UIDSet([200...299]).suffix(1), UIDSet([299]))
        XCTAssertEqual(UIDSet([200...299]).suffix(2), UIDSet([298...299]))
        XCTAssertEqual(UIDSet([200...299]).suffix(3), UIDSet([297...299]))

        XCTAssertEqual(UIDSet([100, 200...299]).suffix(0), UIDSet())
        XCTAssertEqual(UIDSet([100, 200...299]).suffix(1), UIDSet([299]))
        XCTAssertEqual(UIDSet([100, 200...299]).suffix(2), UIDSet([298...299]))
        XCTAssertEqual(UIDSet([100, 200...299]).suffix(3), UIDSet([297...299]))

        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(0), UIDSet())
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(1), UIDSet([202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(2), UIDSet([201...202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(3), UIDSet([200...202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(4), UIDSet([102, 200...202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(5), UIDSet([101...102, 200...202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(6), UIDSet([100...102, 200...202]))
        XCTAssertEqual(UIDSet([100...102, 200...202]).suffix(7), UIDSet([100...102, 200...202]))

        XCTAssertEqual(UIDSet.all.suffix(0), UIDSet())
        XCTAssertEqual(UIDSet.all.suffix(1), UIDSet([4_294_967_295]))
        XCTAssertEqual(UIDSet.all.suffix(2), UIDSet([4_294_967_294...4_294_967_295]))
    }
}
