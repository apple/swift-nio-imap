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
    @Test(
        "parse - partial and section cases",
        arguments: [
            ParseFixture.urlFetchType(
                ";PARTIAL=1.2",
                expected: .success(.partialOnly(.init(range: .init(offset: 1, length: 2))))
            ),
            ParseFixture.urlFetchType(
                ";SECTION=test",
                expected: .success(
                    .sectionPartial(section: .init(encodedSection: "test"), partial: nil)
                )
            ),
            ParseFixture.urlFetchType(
                ";SECTION=test/;PARTIAL=1.2",
                expected: .success(
                    .sectionPartial(
                        section: .init(encodedSection: "test"),
                        partial: .init(range: .init(offset: 1, length: 2))
                    )
                )
            ),
        ]
    )
    func parsePartialAndSectionCases(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test(
        "parse - UID cases",
        arguments: [
            ParseFixture.urlFetchType(
                ";UID=123",
                expected: .success(.uidSectionPartial(uid: .init(uid: 123), section: nil, partial: nil))
            ),
            ParseFixture.urlFetchType(
                ";UID=123/;SECTION=test",
                expected: .success(
                    .uidSectionPartial(
                        uid: .init(uid: 123),
                        section: .init(encodedSection: "test"),
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
                        section: .init(encodedSection: "test"),
                        partial: .init(range: .init(offset: 1, length: 2))
                    )
                )
            ),
        ]
    )
    func parseUIDCases(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test(
        "parse - ref cases 1",
        arguments: [
            ParseFixture.urlFetchType(
                "test;UID=123",
                expected: .success(
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: "test"),
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
                        ref: .init(encodeMailbox: "test"),
                        uid: .init(uid: 123),
                        section: .init(encodedSection: "section"),
                        partial: nil
                    )
                )
            ),
        ]
    )
    func parseRefCases1(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }

    @Test(
        "parse - ref cases 2",
        arguments: [
            ParseFixture.urlFetchType(
                "test;UID=123/;PARTIAL=1.2",
                expected: .success(
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: "test"),
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
                        ref: .init(encodeMailbox: "test"),
                        uid: .init(uid: 123),
                        section: .init(encodedSection: "section"),
                        partial: .init(range: .init(offset: 1, length: 2))
                    )
                )
            ),
        ]
    )
    func parseRefCases2(_ fixture: ParseFixture<URLFetchType>) {
        fixture.checkParsing()
    }
}

// MARK: -

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
