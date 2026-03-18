//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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

@Suite("MailboxGroup")
struct MailboxGroupTests {
    @Test(
        "encode email address group",
        arguments: [
            EncodeFixture.emailAddressGroup(
                EmailAddressGroup(
                    groupName: ByteBuffer(string: "Team"),
                    sourceRoot: ByteBuffer(string: "root"),
                    children: [
                        .singleAddress(
                            EmailAddress(
                                personName: "Alice",
                                sourceRoot: nil,
                                mailbox: "alice",
                                host: "example.com"
                            )
                        )
                    ]
                ),
                #"(NIL "root" "Team" NIL)("Alice" NIL "alice" "example.com")(NIL "root" NIL NIL)"#
            )
        ]
    )
    func encodeEmailAddressGroup(_ fixture: EncodeFixture<EmailAddressGroup>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode email address or group",
        arguments: [
            EncodeFixture.emailAddressOrGroup(
                .group(
                    EmailAddressGroup(
                        groupName: ByteBuffer(string: "Mgmt"),
                        sourceRoot: nil,
                        children: []
                    )
                ),
                #"(NIL NIL "Mgmt" NIL)(NIL NIL NIL NIL)"#
            )
        ]
    )
    func encodeEmailAddressOrGroup(_ fixture: EncodeFixture<EmailAddressListElement>) {
        fixture.checkEncoding()
    }
}

// MARK: - Fixtures

extension EncodeFixture<EmailAddressGroup> {
    fileprivate static func emailAddressGroup(
        _ input: EmailAddressGroup,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEmailAddressGroup($1) }
        )
    }
}

extension EncodeFixture<EmailAddressListElement> {
    fileprivate static func emailAddressOrGroup(
        _ input: EmailAddressListElement,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEmailAddressOrGroup($1) }
        )
    }
}
