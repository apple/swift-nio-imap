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

@Suite("MessagePath.ByteRange")
struct MessagePathByteRangeTests {
    @Test(arguments: [
        EncodeFixture.messagePathByteRange(
            .init(range: .init(offset: 1, length: nil)),
            "/;PARTIAL=1"
        ),
        EncodeFixture.messagePathByteRange(
            .init(range: .init(offset: 1, length: 2)),
            "/;PARTIAL=1.2"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessagePath.ByteRange>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse with slash",
        arguments: [
            ParseFixture.parseWithSlash("/;PARTIAL=1", expected: .success(.init(range: .init(offset: 1, length: nil)))),
            ParseFixture.parseWithSlash("/;PARTIAL=1.2", expected: .success(.init(range: .init(offset: 1, length: 2)))),
            ParseFixture.parseWithSlash("/;PARTIAL=a", expected: .failure),
            ParseFixture.parseWithSlash("PARTIAL=a", expected: .failure),
            ParseFixture.parseWithSlash("/;PARTIAL=1", "", expected: .incompleteMessage),
        ]
    )
    func parseWithSlash(_ fixture: ParseFixture<MessagePath.ByteRange>) {
        fixture.checkParsing()
    }

    @Test(
        "parse without slash",
        arguments: [
            ParseFixture.parseWithoutSlash(
                ";PARTIAL=1",
                expected: .success(.init(range: .init(offset: 1, length: nil)))
            ),
            ParseFixture.parseWithoutSlash(
                ";PARTIAL=1.2",
                expected: .success(.init(range: .init(offset: 1, length: 2)))
            ),
            ParseFixture.parseWithoutSlash(";PARTIAL=a", expected: .failure),
            ParseFixture.parseWithoutSlash("PARTIAL=a", expected: .failure),
            ParseFixture.parseWithoutSlash(";PARTIAL=1", "", expected: .incompleteMessage),
        ]
    )
    func parseWithoutSlash(_ fixture: ParseFixture<MessagePath.ByteRange>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<MessagePath.ByteRange> {
    fileprivate static func messagePathByteRange(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeMessagePathByteRange($1) }
        )
    }
}

extension ParseFixture<MessagePath.ByteRange> {
    fileprivate static func parseWithSlash(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessagePathByteRange
        )
    }

    fileprivate static func parseWithoutSlash(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessagePathByteRangeOnly
        )
    }
}
