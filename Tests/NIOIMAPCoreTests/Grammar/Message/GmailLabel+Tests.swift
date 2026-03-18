//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

@Suite("GmailLabel")
struct GmailLabelTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.gmailLabel(GmailLabel(ByteBuffer(string: "Inbox")), #""Inbox""#),
            EncodeFixture.gmailLabel(GmailLabel(ByteBuffer(string: "\\Sent")), #"\Sent"#),
            EncodeFixture.gmailLabel(GmailLabel(ByteBuffer(string: "My Label")), #""My Label""#),
        ]
    )
    func encode(_ fixture: EncodeFixture<GmailLabel>) {
        fixture.checkEncoding()
    }

    @Test("init from mailbox name")
    func initFromMailboxName() {
        let mailbox = MailboxName("Sent")
        let label = GmailLabel(mailboxName: mailbox)
        let encoded = EncodeBuffer.makeDescription { _ = $0.writeGmailLabel(label) }
        #expect(encoded == "\"Sent\"")
    }

    @Test("init from use attribute")
    func initFromUseAttribute() {
        let attr = UseAttribute("\\Sent")
        let label = GmailLabel(useAttribute: attr)
        let encoded = EncodeBuffer.makeDescription { _ = $0.writeGmailLabel(label) }
        #expect(encoded == "\\Sent")
    }

    @Test(
        "makeDisplayString",
        arguments: [
            (GmailLabel(ByteBuffer(string: "Inbox")), "Inbox"),
            (GmailLabel(ByteBuffer(string: "&invalid-")), "&invalid-"),  // invalid modified UTF-7 falls back to UTF-8
        ] as [(GmailLabel, String)]
    )
    func makeDisplayString(_ fixture: (GmailLabel, String)) {
        #expect(fixture.0.makeDisplayString() == fixture.1)
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.gmailLabel(#""Inbox""#, expected: .success(GmailLabel(ByteBuffer(string: "Inbox")))),
            ParseFixture.gmailLabel(#"\Sent"#, expected: .success(GmailLabel(ByteBuffer(string: "\\Sent")))),
            ParseFixture.gmailLabel("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<GmailLabel>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<GmailLabel> {
    fileprivate static func gmailLabel(_ input: GmailLabel, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeGmailLabel($1) }
        )
    }
}

extension ParseFixture<GmailLabel> {
    fileprivate static func gmailLabel(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseGmailLabel
        )
    }
}
