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

class StatusAttributeTests: EncodeTestClass {}

// MARK: - [StatusAttribute] imapEncoded

extension StatusAttributeTests {
    func testStatusAttribute_ImapEncodedEmpty() {
        let expected = ""
        let size = self.testBuffer.writeStatusAttributes([])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testStatusAttribute_ImapEncodedFull() {
        let expected = "MESSAGES RECENT UNSEEN"
        let size = self.testBuffer.writeStatusAttributes([NIOIMAP.MailboxAttribute.messages, .recent, .unseen])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
