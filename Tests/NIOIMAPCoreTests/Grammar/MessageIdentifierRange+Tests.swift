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

class MessageIdentifierRange_Tests: EncodeTestClass {}

// MARK: - Conversion

extension MessageIdentifierRange_Tests {
    func testConvert_sequenceNumber() {
        let input = MessageIdentifierRange<UnknownMessageIdentifier>(UnknownMessageIdentifier(1)...2)
        let output = MessageIdentifierRange<SequenceNumber>(input)
        XCTAssertEqual(output, 1...2)
    }

    func testConvert_uid() {
        let input = MessageIdentifierRange<UnknownMessageIdentifier>(UnknownMessageIdentifier(5)...6)
        let output = MessageIdentifierRange<UID>(input)
        XCTAssertEqual(output, 5...6)
    }
}
