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

@Suite("Expire")
struct ExpireTests {
    @Test(arguments: [
        EncodeFixture.expire(
            .init(
                dateTime: .init(
                    date: .init(year: 1234, month: 12, day: 20),
                    time: .init(hour: 12, minute: 34, second: 56, fraction: 123456)
                )
            ),
            ";EXPIRE=1234-12-20T12:34:56.123456"
        ),
        EncodeFixture.expire(
            .init(
                dateTime: .init(
                    date: .init(year: 2025, month: 1, day: 1),
                    time: .init(hour: 0, minute: 0, second: 0, fraction: 0)
                )
            ),
            ";EXPIRE=2025-01-01T00:00:00.0"
        ),
        EncodeFixture.expire(
            .init(
                dateTime: .init(
                    date: .init(year: 2099, month: 12, day: 31),
                    time: .init(hour: 23, minute: 59, second: 59, fraction: 999999)
                )
            ),
            ";EXPIRE=2099-12-31T23:59:59.999999"
        ),
    ])
    func encode(_ fixture: EncodeFixture<Expire>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.expire(
            ";EXPIRE=1234-12-20T12:34:56",
            "\r",
            expected: .success(
                Expire(
                    dateTime: FullDateTime(
                        date: FullDate(year: 1234, month: 12, day: 20),
                        time: FullTime(hour: 12, minute: 34, second: 56)
                    )
                )
            )
        ),
        ParseFixture.expire(
            ";EXPIRE=1234-12-20t12:34:56",
            "\r",
            expected: .success(
                Expire(
                    dateTime: FullDateTime(
                        date: FullDate(year: 1234, month: 12, day: 20),
                        time: FullTime(hour: 12, minute: 34, second: 56)
                    )
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<Expire>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<Expire> {
    fileprivate static func expire(
        _ input: Expire,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExpire($1) }
        )
    }
}

extension ParseFixture<Expire> {
    fileprivate static func expire(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseExpire
        )
    }
}
