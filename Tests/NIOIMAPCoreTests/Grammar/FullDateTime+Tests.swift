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

@Suite("FullDateTime")
struct FullDateTimeTests {
    @Test(arguments: [
        EncodeFixture.fullDateTime(
            .init(date: .init(year: 1, month: 2, day: 3), time: .init(hour: 4, minute: 5, second: 6)),
            "0001-02-03T04:05:06"
        ),
        EncodeFixture.fullDateTime(
            .init(date: .init(year: 2025, month: 1, day: 1), time: .init(hour: 0, minute: 0, second: 0)),
            "2025-01-01T00:00:00"
        ),
        EncodeFixture.fullDateTime(
            .init(date: .init(year: 2025, month: 12, day: 31), time: .init(hour: 23, minute: 59, second: 59)),
            "2025-12-31T23:59:59"
        ),
        EncodeFixture.fullDateTime(
            .init(date: .init(year: 2024, month: 6, day: 15), time: .init(hour: 12, minute: 30, second: 45)),
            "2024-06-15T12:30:45"
        ),
        EncodeFixture.fullDateTime(
            .init(date: .init(year: 9999, month: 12, day: 31), time: .init(hour: 23, minute: 59, second: 59)),
            "9999-12-31T23:59:59"
        ),
    ])
    func `encode full date time`(_ fixture: EncodeFixture<FullDateTime>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.fullDate(.init(year: 1, month: 2, day: 3), "0001-02-03"),
        EncodeFixture.fullDate(.init(year: 2025, month: 1, day: 1), "2025-01-01"),
        EncodeFixture.fullDate(.init(year: 2025, month: 12, day: 31), "2025-12-31"),
        EncodeFixture.fullDate(.init(year: 2024, month: 2, day: 29), "2024-02-29"),
        EncodeFixture.fullDate(.init(year: 2024, month: 6, day: 15), "2024-06-15"),
        EncodeFixture.fullDate(.init(year: 9999, month: 12, day: 31), "9999-12-31"),
    ])
    func `encode full date`(_ fixture: EncodeFixture<FullDate>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.fullTime(.init(hour: 0, minute: 0, second: 0), "00:00:00"),
        EncodeFixture.fullTime(.init(hour: 1, minute: 2, second: 3), "01:02:03"),
        EncodeFixture.fullTime(.init(hour: 12, minute: 30, second: 45), "12:30:45"),
        EncodeFixture.fullTime(.init(hour: 23, minute: 59, second: 59), "23:59:59"),
        EncodeFixture.fullTime(.init(hour: 1, minute: 2, second: 3, fraction: 4), "01:02:03.4"),
        EncodeFixture.fullTime(.init(hour: 12, minute: 30, second: 45, fraction: 123), "12:30:45.123"),
        EncodeFixture.fullTime(.init(hour: 0, minute: 0, second: 0, fraction: 1), "00:00:00.1"),
    ])
    func `encode full time`(_ fixture: EncodeFixture<FullTime>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.fullDateTime(
            "1234-12-20T11:22:33",
            " ",
            expected: .success(
                .init(
                    date: .init(year: 1234, month: 12, day: 20),
                    time: .init(hour: 11, minute: 22, second: 33)
                )
            )
        )
    ])
    func `parse full date time`(_ fixture: ParseFixture<FullDateTime>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.fullDate("1234-12-23", " ", expected: .success(.init(year: 1234, month: 12, day: 23))),
        ParseFixture.fullDate("a", "", expected: .failure),
        ParseFixture.fullDate("1234", "", expected: .incompleteMessage),
    ])
    func `parse full date`(_ fixture: ParseFixture<FullDate>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.fullTime("12:34:56", " ", expected: .success(.init(hour: 12, minute: 34, second: 56))),
        ParseFixture.fullTime(
            "12:34:56.123456",
            " ",
            expected: .success(.init(hour: 12, minute: 34, second: 56, fraction: 123456))
        ),
        ParseFixture.fullTime("a", "", expected: .failure),
        ParseFixture.fullTime("1234:56:12", "", expected: .failure),
        ParseFixture.fullTime("1234", "", expected: .incompleteMessage),
    ])
    func `parse full time`(_ fixture: ParseFixture<FullTime>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<FullDateTime> {
    fileprivate static func fullDateTime(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFullDateTime($1) }
        )
    }
}

extension EncodeFixture<FullDate> {
    fileprivate static func fullDate(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFullDate($1) }
        )
    }
}

extension EncodeFixture<FullTime> {
    fileprivate static func fullTime(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFullTime($1) }
        )
    }
}

extension ParseFixture<FullDateTime> {
    fileprivate static func fullDateTime(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFullDateTime
        )
    }
}

extension ParseFixture<FullDate> {
    fileprivate static func fullDate(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFullDate
        )
    }
}

extension ParseFixture<FullTime> {
    fileprivate static func fullTime(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFullTime
        )
    }
}
