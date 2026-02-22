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

@Suite("AppendMessage")
struct AppendMessageTests {
    @Test(arguments: [
        EncodeFixture.appendMessage(
            .init(options: .none, data: .init(byteCount: 123)),
            .rfc3501,
            " {123}\r\n"
        ),
        EncodeFixture.appendMessage(
            .init(
                options: .init(flagList: [.draft, .flagged], internalDate: nil, extensions: [:]),
                data: .init(byteCount: 123)
            ),
            .rfc3501,
            " (\\Draft \\Flagged) {123}\r\n"
        ),
        EncodeFixture.appendMessage(
            .init(
                options: .init(
                    flagList: [.draft, .flagged],
                    internalDate: ServerMessageDate(
                        ServerMessageDate.Components(
                            year: 2020,
                            month: 7,
                            day: 2,
                            hour: 13,
                            minute: 42,
                            second: 52,
                            timeZoneMinutes: 60
                        )!
                    ),
                    extensions: [:]
                ),
                data: .init(byteCount: 123)
            ),
            .rfc3501,
            " (\\Draft \\Flagged) \"2-Jul-2020 13:42:52 +0100\" {123}\r\n"
        ),
        EncodeFixture.appendMessage(
            .init(
                options: .init(
                    flagList: [],
                    internalDate: ServerMessageDate(
                        ServerMessageDate.Components(
                            year: 2020,
                            month: 7,
                            day: 2,
                            hour: 13,
                            minute: 42,
                            second: 52,
                            timeZoneMinutes: 60
                        )!
                    ),
                    extensions: [:]
                ),
                data: .init(byteCount: 456)
            ),
            .literalPlus,
            " \"2-Jul-2020 13:42:52 +0100\" {456+}\r\n"
        ),
        EncodeFixture.appendMessage(
            .init(options: .none, data: .init(byteCount: 456)),
            .literalPlus,
            " {456+}\r\n"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AppendMessage>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.appendMessage(
            " (\\Answered) {123}\r\n",
            "test",
            expected: .success(
                .init(
                    options: .init(flagList: [.answered], internalDate: nil, extensions: [:]),
                    data: .init(byteCount: 123)
                )
            )
        ),
        ParseFixture.appendMessage(
            " (\\Answered) ~{456}\r\n",
            "test",
            expected: .success(
                .init(
                    options: .init(flagList: [.answered], internalDate: nil, extensions: [:]),
                    data: .init(byteCount: 456, withoutContentTransferEncoding: true)
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<AppendMessage>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AppendMessage> {
    fileprivate static func appendMessage(
        _ input: AppendMessage,
        _ options: CommandEncodingOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(options),
            expectedString: expectedString,
            encoder: { $0.writeAppendMessage($1) }
        )
    }
}

extension ParseFixture<AppendMessage> {
    fileprivate static func appendMessage(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAppendMessage
        )
    }
}
