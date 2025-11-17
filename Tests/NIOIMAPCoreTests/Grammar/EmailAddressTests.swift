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

class EmailAddressTests: EncodeTestClass {}

// MARK: - Address init

extension EmailAddressTests {
    func testInit() {
        let name: ByteBuffer? = "a"
        let adl: ByteBuffer? = "b"
        let mailbox: ByteBuffer? = "c"
        let host: ByteBuffer? = "d"
        let address = EmailAddress(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)

        XCTAssertEqual(address.personName, name)
        XCTAssertEqual(address.sourceRoot, adl)
        XCTAssertEqual(address.mailbox, mailbox)
        XCTAssertEqual(address.host, host)
    }
}

// MARK: - Address imapEncoded

extension EmailAddressTests {
    func testAllNil() {
        let address = EmailAddress(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)
        let expected = "(NIL NIL NIL NIL)"
        let size = self.testBuffer.writeEmailAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testNoneNil() {
        let address = EmailAddress(
            personName: "somename",
            sourceRoot: "someadl",
            mailbox: "somemailbox",
            host: "someaddress"
        )
        let expected = "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
        let size = self.testBuffer.writeEmailAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testMixture() {
        let address = EmailAddress(personName: nil, sourceRoot: "some", mailbox: "thing", host: nil)
        let expected = "(NIL \"some\" \"thing\" NIL)"
        let size = self.testBuffer.writeEmailAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testUnicode() {
        let address = EmailAddress(personName: nil, sourceRoot: nil, mailbox: "阿Q", host: "例子.中国")
        let expected = "(NIL NIL {4}\r\n阿Q {13}\r\n例子.中国)"
        let size = self.testBuffer.writeEmailAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
