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

    @Test("parse - partial and section cases", arguments: [
        ParseFixture.urlFetchType(
            ";PARTIAL=1.2",
            expected: .success(.partialOnly(.init(range: .init(offset: 1, length: 2))))
        ),
        ParseFixture.urlFetchType(
            ";SECTION=test",
            expected: .success(.sectionPartial(section: .init(encodedSection: .init(section: "test")), partial: nil))
        ),
        ParseFixture.urlFetchType(
            ";SECTION=test/;PARTIAL=1.2",
            expected: .success(
                .sectionPartial(
                    section: .init(encodedSection: .init(section: "test")),
                    partial: .init(range: .init(offset: 1, length: 2))
                )
            )
        ),
    ])
    func parsePartialAndSectionCases(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test("parse - UID cases", arguments: [
        ParseFixture.urlFetchType(
            ";UID=123",
            expected: .success(.uidSectionPartial(uid: .init(uid: 123), section: nil, partial: nil))
        ),
        ParseFixture.urlFetchType(
            ";UID=123/;SECTION=test",
            expected: .success(
                .uidSectionPartial(
                    uid: .init(uid: 123),
                    section: .init(encodedSection: .init(section: "test")),
                    partial: nil
                )
            )
        ),
        ParseFixture.urlFetchType(
            ";UID=123/;PARTIAL=1.2",
            expected: .success(
                .uidSectionPartial(
                    uid: .init(uid: 123),
                    section: nil,
                    partial: .init(range: .init(offset: 1, length: 2))
                )
            )
        ),
        ParseFixture.urlFetchType(
            ";UID=123/;SECTION=test/;PARTIAL=1.2",
            expected: .success(
                .uidSectionPartial(
                    uid: .init(uid: 123),
                    section: .init(encodedSection: .init(section: "test")),
                    partial: .init(range: .init(offset: 1, length: 2))
                )
            )
        ),
    ])
    func parseUIDCases(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test("parse - ref cases 1", arguments: [
        ParseFixture.urlFetchType(
            "test;UID=123",
            expected: .success(
                .refUidSectionPartial(
                    ref: .init(encodeMailbox: .init(mailbox: "test")),
                    uid: .init(uid: 123),
                    section: nil,
                    partial: nil
                )
            )
        ),
        ParseFixture.urlFetchType(
            "test;UID=123/;SECTION=section",
            expected: .success(
                .refUidSectionPartial(
                    ref: .init(encodeMailbox: .init(mailbox: "test")),
                    uid: .init(uid: 123),
                    section: .init(encodedSection: .init(section: "section")),
                    partial: nil
                )
            )
        ),
    ])
    func parseRefCases1(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test("parse - ref cases 2", arguments: [
        ParseFixture.urlFetchType(
            "test;UID=123/;PARTIAL=1.2",
            expected: .success(
                .refUidSectionPartial(
                    ref: .init(encodeMailbox: .init(mailbox: "test")),
                    uid: .init(uid: 123),
                    section: nil,
                    partial: .init(range: .init(offset: 1, length: 2))
                )
            )
        ),
        ParseFixture.urlFetchType(
            "test;UID=123/;SECTION=section/;PARTIAL=1.2",
            expected: .success(
                .refUidSectionPartial(
                    ref: .init(encodeMailbox: .init(mailbox: "test")),
                    uid: .init(uid: 123),
                    section: .init(encodedSection: .init(section: "section")),
                    partial: .init(range: .init(offset: 1, length: 2))
                )
            )
        ),
    ])
    func parseRefCases2(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
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

extension ParseFixture<URLFetchType> {
    fileprivate static func urlFetchType(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseURLFetchType
        )
    }
}
