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
}
