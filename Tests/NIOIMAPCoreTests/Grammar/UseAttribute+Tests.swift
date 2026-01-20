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

@Suite("UseAttribute")
struct UseAttributeTests {
    @Test(arguments: [
        EncodeFixture.useAttribute(.all, "\\All"),
        EncodeFixture.useAttribute(.archive, "\\Archive"),
        EncodeFixture.useAttribute(.drafts, "\\Drafts"),
        EncodeFixture.useAttribute(.flagged, "\\Flagged"),
        EncodeFixture.useAttribute(.junk, "\\Junk"),
        EncodeFixture.useAttribute(.sent, "\\Sent"),
        EncodeFixture.useAttribute(.trash, "\\Trash"),
        EncodeFixture.useAttribute(.init("\\test"), "\\test"),
    ])
    func encode(_ fixture: EncodeFixture<UseAttribute>) {
        fixture.checkEncoding()
    }

    @Test func `lowercasing behavior`() {
        let t1 = UseAttribute("TEST")
        let t2 = UseAttribute("test")
        #expect(t1 == t2)
        #expect(t1.stringValue == "TEST")
        #expect(t2.stringValue == "test")
    }

    @Test func `convert from mailbox info attribute`() {
        #expect(UseAttribute(MailboxInfo.Attribute(#"\All"#)).stringValue == #"\All"#)
    }
}

// MARK: -

extension EncodeFixture<UseAttribute> {
    fileprivate static func useAttribute(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUseAttribute($1) }
        )
    }
}
