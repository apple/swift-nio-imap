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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("EmailAddress")
struct EmailAddressTestsSuite {
    @Test func `address initialization with properties`() {
        let name: ByteBuffer? = "a"
        let adl: ByteBuffer? = "b"
        let mailbox: ByteBuffer? = "c"
        let host: ByteBuffer? = "d"
        let address = EmailAddress(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)

        #expect(address.personName == name)
        #expect(address.sourceRoot == adl)
        #expect(address.mailbox == mailbox)
        #expect(address.host == host)
    }

    @Test(arguments: [
        EmailAddressFixture(
            name: "all nil",
            address: .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
            expectedString: "(NIL NIL NIL NIL)"
        ),
        EmailAddressFixture(
            name: "none nil",
            address: .init(personName: "somename", sourceRoot: "someadl", mailbox: "somemailbox", host: "someaddress"),
            expectedString: "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
        ),
        EmailAddressFixture(
            name: "mixed nil",
            address: .init(personName: nil, sourceRoot: "some", mailbox: "thing", host: nil),
            expectedString: "(NIL \"some\" \"thing\" NIL)"
        ),
        EmailAddressFixture(
            name: "unicode",
            address: .init(personName: nil, sourceRoot: nil, mailbox: "阿Q", host: "例子.中国"),
            expectedString: "(NIL NIL {4}\r\n阿Q {13}\r\n例子.中国)"
        ),
    ])
    func `encode email address`(_ fixture: EmailAddressFixture) {
        fixture.checkEncoding()
    }
}

// MARK: -

struct EmailAddressFixture: Sendable, CustomTestStringConvertible {
    var name: String
    var address: EmailAddress
    var expectedString: String

    var testDescription: String { name }

    func checkEncoding() {
        let buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        var testBuffer = buffer
        let size = testBuffer.writeEmailAddress(address)
        var remaining = testBuffer
        let chunk = remaining.nextChunk()
        let actualString = String(buffer: chunk.bytes)

        #expect(size == expectedString.utf8.count)
        #expect(actualString.mappingControlPictures() == expectedString.mappingControlPictures())
    }
}
