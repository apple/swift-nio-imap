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
    @Test(
        "encode full date time",
        arguments: [
            EncodeFixture.fullDateTime(
                .init(date: .init(year: 1, month: 2, day: 3), time: .init(hour: 4, minute: 5, second: 6, offset: .utc)),
                "0001-02-03T04:05:06Z"
            ),
            EncodeFixture.fullDateTime(
                .init(
                    date: .init(year: 2025, month: 1, day: 1),
                    time: .init(hour: 0, minute: 0, second: 0, offset: .utc)
                ),
                "2025-01-01T00:00:00Z"
            ),
            EncodeFixture.fullDateTime(
                .init(
                    date: .init(year: 2025, month: 12, day: 31),
                    time: .init(hour: 23, minute: 59, second: 59, offset: .utc)
                ),
                "2025-12-31T23:59:59Z"
            ),
            EncodeFixture.fullDateTime(
                .init(
                    date: .init(year: 2024, month: 6, day: 15),
                    time: .init(hour: 12, minute: 30, second: 45, offset: .utc)
                ),
                "2024-06-15T12:30:45Z"
            ),
            EncodeFixture.fullDateTime(
                .init(
                    date: .init(year: 9999, month: 12, day: 31),
                    time: .init(hour: 23, minute: 59, second: 59, offset: .utc)
                ),
                "9999-12-31T23:59:59Z"
            ),
        ]
    )
    func encodeFullDateTime(_ fixture: EncodeFixture<FullDateTime>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode full date",
        arguments: [
            EncodeFixture.fullDate(.init(year: 1, month: 2, day: 3), "0001-02-03"),
            EncodeFixture.fullDate(.init(year: 2025, month: 1, day: 1), "2025-01-01"),
            EncodeFixture.fullDate(.init(year: 2025, month: 12, day: 31), "2025-12-31"),
            EncodeFixture.fullDate(.init(year: 2024, month: 2, day: 29), "2024-02-29"),
            EncodeFixture.fullDate(.init(year: 2024, month: 6, day: 15), "2024-06-15"),
            EncodeFixture.fullDate(.init(year: 9999, month: 12, day: 31), "9999-12-31"),
        ]
    )
    func encodeFullDate(_ fixture: EncodeFixture<FullDate>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode full time",
        arguments: [
            EncodeFixture.fullTime(.init(hour: 0, minute: 0, second: 0, offset: .utc), "00:00:00Z"),
            EncodeFixture.fullTime(.init(hour: 1, minute: 2, second: 3, offset: .utc), "01:02:03Z"),
            EncodeFixture.fullTime(.init(hour: 12, minute: 30, second: 45, offset: .utc), "12:30:45Z"),
            EncodeFixture.fullTime(.init(hour: 23, minute: 59, second: 59, offset: .utc), "23:59:59Z"),
            EncodeFixture.fullTime(.init(hour: 1, minute: 2, second: 3, fraction: "4", offset: .utc), "01:02:03.4Z"),
            EncodeFixture.fullTime(
                .init(hour: 12, minute: 30, second: 45, fraction: "123", offset: .utc),
                "12:30:45.123Z"
            ),
            EncodeFixture.fullTime(.init(hour: 0, minute: 0, second: 0, fraction: "1", offset: .utc), "00:00:00.1Z"),
            EncodeFixture.fullTime(
                .init(hour: 1, minute: 2, second: 3, offset: .plus(hour: 1, minute: 30)),
                "01:02:03+01:30"
            ),
            EncodeFixture.fullTime(
                .init(hour: 1, minute: 2, second: 3, offset: .minus(hour: 8, minute: 0)),
                "01:02:03-08:00"
            ),
        ]
    )
    func encodeFullTime(_ fixture: EncodeFixture<FullTime>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse full date time",
        arguments: [
            ParseFixture.fullDateTime(
                "1234-12-20T11:22:33Z",
                " ",
                expected: .success(
                    .init(
                        date: .init(year: 1234, month: 12, day: 20),
                        time: .init(hour: 11, minute: 22, second: 33, offset: .utc)
                    )
                )
            )
        ]
    )
    func parseFullDateTime(_ fixture: ParseFixture<FullDateTime>) {
        fixture.checkParsing()
    }

    @Test(
        "parse full date",
        arguments: [
            ParseFixture.fullDate("1234-12-23", " ", expected: .success(.init(year: 1234, month: 12, day: 23))),
            ParseFixture.fullDate("a", "", expected: .failure),
            ParseFixture.fullDate("1234", "", expected: .incompleteMessage),
        ]
    )
    func parseFullDate(_ fixture: ParseFixture<FullDate>) {
        fixture.checkParsing()
    }

    @Test(
        "parse full time",
        arguments: [
            ParseFixture.fullTime(
                "12:34:56Z",
                " ",
                expected: .success(.init(hour: 12, minute: 34, second: 56, offset: .utc))
            ),
            ParseFixture.fullTime(
                "12:34:56.123456Z",
                " ",
                expected: .success(.init(hour: 12, minute: 34, second: 56, fraction: "123456", offset: .utc))
            ),
            ParseFixture.fullTime("a", "", expected: .failure),
            ParseFixture.fullTime(
                "12:34:56z",
                " ",
                expected: .success(.init(hour: 12, minute: 34, second: 56, offset: .utc))
            ),
            ParseFixture.fullTime(
                "12:34:56+01:30",
                " ",
                expected: .success(.init(hour: 12, minute: 34, second: 56, offset: .plus(hour: 1, minute: 30)))
            ),
            ParseFixture.fullTime(
                "12:34:56-00:00",
                " ",
                expected: .success(.init(hour: 12, minute: 34, second: 56, offset: .minus(hour: 0, minute: 0)))
            ),
            // RFC 3339 `full-time`: the offset is required.
            ParseFixture.fullTime("12:34:56", " ", expected: .failureIgnoringBufferModifications),
            ParseFixture.fullTime("12:34:56+0130", " ", expected: .failureIgnoringBufferModifications),
            // `time-hour` / `time-minute` ranges: the encoder asserts on anything else.
            ParseFixture.fullTime("12:34:56+24:00", " ", expected: .failureIgnoringBufferModifications),
            ParseFixture.fullTime("12:34:56-01:60", " ", expected: .failureIgnoringBufferModifications),
            ParseFixture.fullTime("1234:56:12", "", expected: .failure),
            ParseFixture.fullTime("1234", "", expected: .incompleteMessage),
        ]
    )
    func parseFullTime(_ fixture: ParseFixture<FullTime>) {
        fixture.checkParsing()
    }

    @Test(
        "parse then encode reproduces the input",
        arguments: ["12:34:56Z", "12:34:56.5Z", "12:34:56.05Z", "12:34:56.000Z", "12:34:56.123456Z"]
    )
    func parseThenEncode(_ input: String) throws {
        var parseBuffer = ParseBuffer(ByteBuffer(string: input + " "))
        let parsed = try GrammarParser().parseFullTime(buffer: &parseBuffer, tracker: .testTracker)
        var encodeBuffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        encodeBuffer.writeFullTime(parsed)
        #expect(String(buffer: encodeBuffer.nextChunk().bytes) == input)
    }

    @Test("invalid fraction is rejected", arguments: ["", " 1", "1a", "-1", "1.5", "\u{0663}"])
    func invalidFraction(_ digits: String) {
        #expect(FullTime.Fraction(digits) == nil)
    }

    @Test("valid fraction is accepted", arguments: ["0", "05", "000", "123456"])
    func validFraction(_ digits: String) {
        #expect(FullTime.Fraction(digits).map { String($0) } == digits)
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("invalid month triggers precondition failure") func invalidMonthPrecondition() async {
        await #expect(
            processExitsWith: ExitTest.Condition.failure,
            performing: {
                _ = FullDate(year: 2024, month: 0, day: 1)
            }
        )
    }

    @Test("invalid day triggers precondition failure") func invalidDayPrecondition() async {
        await #expect(
            processExitsWith: ExitTest.Condition.failure,
            performing: {
                _ = FullDate(year: 2024, month: 1, day: 0)
            }
        )
    }

    #if DEBUG
    @Test("an out-of-range offset asserts on encode") func outOfRangeOffsetAsserts() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                var buffer = EncodeBuffer.serverEncodeBuffer(
                    buffer: ByteBuffer(),
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                buffer.writeTimeOffset(.plus(hour: 100, minute: 0))
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid time offset")
    }
    #endif

    @Test("an invalid fraction literal traps") func fractionLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let fraction: FullTime.Fraction = "1a"
                _ = fraction
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid fraction")
    }
    #endif
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
