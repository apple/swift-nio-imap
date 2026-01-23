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
import Testing

@Suite("MessagePath")
struct MessagePathTests {
    @Test(arguments: [
        EncodeFixture.messagePath(
            .init(
                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                iUID: .init(uid: 123),
                section: nil,
                range: nil
            ),
            "test/;UID=123"
        ),
        EncodeFixture.messagePath(
            .init(
                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                iUID: .init(uid: 123),
                section: .init(encodedSection: .init(section: "section")),
                range: nil
            ),
            "test/;UID=123/;SECTION=section"
        ),
        EncodeFixture.messagePath(
            .init(
                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                iUID: .init(uid: 123),
                section: nil,
                range: .init(range: .init(offset: 123, length: 4))
            ),
            "test/;UID=123/;PARTIAL=123.4"
        ),
        EncodeFixture.messagePath(
            .init(
                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                iUID: .init(uid: 123),
                section: .init(encodedSection: .init(section: "section")),
                range: .init(range: .init(offset: 123, length: 4))
            ),
            "test/;UID=123/;SECTION=section/;PARTIAL=123.4"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessagePath>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MessagePath> {
    fileprivate static func messagePath(
        _ input: MessagePath,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessagePath($1) }
        )
    }
}
