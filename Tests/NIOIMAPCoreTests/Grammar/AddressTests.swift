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

class AddressTests: EncodeTestClass {}

// MARK: - Address init

extension AddressTests {
    func testInit() {
        let name: ByteBuffer? = "a"
        let adl: ByteBuffer? = "b"
        let mailbox: ByteBuffer? = "c"
        let host: ByteBuffer? = "d"
        let address = Address(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)

        XCTAssertEqual(address.personName, name)
        XCTAssertEqual(address.sourceRoot, adl)
        XCTAssertEqual(address.mailbox, mailbox)
        XCTAssertEqual(address.host, host)
    }
}

// MARK: - Address imapEncoded

extension AddressTests {
    func testAllNil() {
        let address = Address(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)
        let expected = "(NIL NIL NIL NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testNoneNil() {
        let address = Address(personName: "somename", sourceRoot: "someadl", mailbox: "somemailbox", host: "someaddress")
        let expected = "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testMixture() {
        let address = Address(personName: nil, sourceRoot: "some", mailbox: "thing", host: nil)
        let expected = "(NIL \"some\" \"thing\" NIL)"
        let size = self.testBuffer.writeAddress(address)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
