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

@Suite("URLFetchType")
struct URLFetchTypeTests {
    @Test(arguments: [
        EncodeFixture.urlFetchType(
            .partialOnly(.init(range: .init(offset: 1, length: 2))),
            ";PARTIAL=1.2"
        ),
        EncodeFixture.urlFetchType(
            .sectionPartial(section: .init(encodedSection: .init(section: "section")), partial: nil),
            ";SECTION=section"
        ),
        EncodeFixture.urlFetchType(
            .sectionPartial(
                section: .init(encodedSection: .init(section: "section")),
                partial: .init(range: .init(offset: 1, length: 2))
            ),
            ";SECTION=section/;PARTIAL=1.2"
        ),
        EncodeFixture.urlFetchType(
            .uidSectionPartial(uid: .init(uid: 123), section: nil, partial: nil),
            ";UID=123"
        ),
        EncodeFixture.urlFetchType(
            .uidSectionPartial(
                uid: .init(uid: 123),
                section: .init(encodedSection: .init(section: "test")),
                partial: nil
            ),
            ";UID=123/;SECTION=test"
        ),
        EncodeFixture.urlFetchType(
            .uidSectionPartial(
                uid: .init(uid: 123),
                section: nil,
                partial: .init(range: .init(offset: 1, length: 2))
            ),
            ";UID=123/;PARTIAL=1.2"
        ),
        EncodeFixture.urlFetchType(
            .uidSectionPartial(
                uid: .init(uid: 123),
                section: .init(encodedSection: .init(section: "test")),
                partial: .init(range: .init(offset: 1, length: 2))
            ),
            ";UID=123/;SECTION=test/;PARTIAL=1.2"
        ),
        EncodeFixture.urlFetchType(
            .refUidSectionPartial(
                ref: .init(encodeMailbox: .init(mailbox: "test")),
                uid: .init(uid: 123),
                section: nil,
                partial: nil
            ),
            "test;UID=123"
        ),
        EncodeFixture.urlFetchType(
            .refUidSectionPartial(
                ref: .init(encodeMailbox: .init(mailbox: "test")),
                uid: .init(uid: 123),
                section: .init(encodedSection: .init(section: "box")),
                partial: nil
            ),
            "test;UID=123/;SECTION=box"
        ),
        EncodeFixture.urlFetchType(
            .refUidSectionPartial(
                ref: .init(encodeMailbox: .init(mailbox: "test")),
                uid: .init(uid: 123),
                section: nil,
                partial: .init(range: .init(offset: 1, length: 2))
            ),
            "test;UID=123/;PARTIAL=1.2"
        ),
        EncodeFixture.urlFetchType(
            .refUidSectionPartial(
                ref: .init(encodeMailbox: .init(mailbox: "test")),
                uid: .init(uid: 123),
                section: .init(encodedSection: .init(section: "box")),
                partial: .init(range: .init(offset: 1, length: 2))
            ),
            "test;UID=123/;SECTION=box/;PARTIAL=1.2"
        ),
    ])
    func encode(_ fixture: EncodeFixture<URLFetchType>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<URLFetchType> {
    fileprivate static func urlFetchType(
        _ input: URLFetchType,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLFetchType($1) }
        )
    }
}
