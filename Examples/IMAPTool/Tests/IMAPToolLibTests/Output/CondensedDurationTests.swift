//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPToolLib
import Testing

/// `formatCondensedDuration(seconds:)` replaces `Date`’s `.components(style:fields:)`
/// format style, which is Darwin-only. These pin the format it has to reproduce.
@Suite("Condensed duration formatting")
enum CondensedDurationTests {
    struct Fixture: CustomTestStringConvertible {
        var seconds: Double
        var expected: String

        var testDescription: String { "\(seconds)" }
    }

    @Test(arguments: [
        // Seconds only.
        Fixture(seconds: 0, expected: "0sec"),
        Fixture(seconds: 1, expected: "1sec"),
        Fixture(seconds: 59, expected: "59sec"),
        // Fractional values truncate towards zero.
        Fixture(seconds: 0.5, expected: "0sec"),
        Fixture(seconds: 4.5, expected: "4sec"),
        Fixture(seconds: 59.9, expected: "59sec"),
        // Whole minutes and hours drop the zero components.
        Fixture(seconds: 60, expected: "1min"),
        Fixture(seconds: 300, expected: "5min"),
        Fixture(seconds: 3600, expected: "1hr"),
        Fixture(seconds: 7200, expected: "2hr"),
        // Mixed components.
        Fixture(seconds: 61, expected: "1min 1sec"),
        Fixture(seconds: 166, expected: "2min 46sec"),
        Fixture(seconds: 3661, expected: "1hr 1min 1sec"),
        Fixture(seconds: 10000, expected: "2hr 46min 40sec"),
        Fixture(seconds: 50000, expected: "13hr 53min 20sec"),
        // An hour with zero minutes keeps the seconds.
        Fixture(seconds: 3601, expected: "1hr 1sec"),
        // Durations beyond a day accumulate into the hour component.
        Fixture(seconds: 90000, expected: "25hr"),
        // Degenerate input must not trap.
        Fixture(seconds: -1, expected: "0sec"),
        Fixture(seconds: .infinity, expected: "0sec"),
        Fixture(seconds: .nan, expected: "0sec"),
        Fixture(seconds: 1e30, expected: "0sec"),
    ])
    static func format(fixture: Fixture) {
        #expect(formatCondensedDuration(seconds: fixture.seconds) == fixture.expected)
    }
}
