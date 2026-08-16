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
import Foundation
import NIOIMAP
import Testing
import ArgumentParser

extension NIOIMAP.Flag {
    static var mailFlagBit0: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit0") }
    static var mailFlagBit1: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit1") }
    static var mailFlagBit2: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit2") }
}

@Suite
private enum MessageFlagTests {
    struct FlagsToSetFixture: Hashable, CustomTestStringConvertible {
        var input: String
        var expected: Set<NIOIMAP.Flag>?

        var testDescription: String { input }
    }

    @Test(arguments: [
        // Standard IMAP flags
        FlagsToSetFixture(
            input: "answered",
            expected: [.answered]
        ),
        FlagsToSetFixture(
            input: "flagged",
            expected: [.flagged]
        ),
        FlagsToSetFixture(
            input: "deleted",
            expected: [.deleted]
        ),
        FlagsToSetFixture(
            input: "seen",
            expected: [.seen]
        ),
        FlagsToSetFixture(
            input: "draft",
            expected: [.draft]
        ),

        // Color flags (use mail flag bits)
        FlagsToSetFixture(
            input: "red",
            expected: [.flagged]
        ),
        FlagsToSetFixture(
            input: "orange",
            expected: [.flagged, .mailFlagBit0]
        ),
        FlagsToSetFixture(
            input: "yellow",
            expected: [.flagged, .mailFlagBit1]
        ),
        FlagsToSetFixture(
            input: "green",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "blue",
            expected: [.flagged, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "purple",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "gray",
            expected: [.flagged, .mailFlagBit1, .mailFlagBit2]
        ),

        // Invalid inputs (should return nil)
        FlagsToSetFixture(
            input: "invalid",
            expected: nil
        ),
        FlagsToSetFixture(
            input: "ANSWERED",  // case sensitive
            expected: nil
        ),
        FlagsToSetFixture(
            input: "",
            expected: nil
        ),
        FlagsToSetFixture(
            input: "unseen",  // not a valid flag
            expected: nil
        ),
        FlagsToSetFixture(
            input: "flag",  // partial match
            expected: nil
        ),
    ])
    static func flagsToSet(
        fixture: FlagsToSetFixture
    ) throws {
        let parsed = MessageFlag(argument: fixture.input)
        if let expected = fixture.expected {
            let p = try #require(parsed)
            #expect(p.flagsToSet == expected)
        } else {
            #expect(parsed == nil)
        }
    }

    @Test(arguments: [
        // Standard IMAP flags (unset themselves)
        FlagsToSetFixture(
            input: "answered",
            expected: [.answered]
        ),
        FlagsToSetFixture(
            input: "flagged",
            expected: [.flagged]
        ),
        FlagsToSetFixture(
            input: "deleted",
            expected: [.deleted]
        ),
        FlagsToSetFixture(
            input: "seen",
            expected: [.seen]
        ),
        FlagsToSetFixture(
            input: "draft",
            expected: [.draft]
        ),

        // Color flags (unset all color flags)
        FlagsToSetFixture(
            input: "red",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "orange",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "yellow",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "green",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "blue",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "purple",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSetFixture(
            input: "gray",
            expected: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),

        // Invalid inputs (should return nil)
        FlagsToSetFixture(
            input: "invalid",
            expected: nil
        ),
        FlagsToSetFixture(
            input: "ANSWERED",  // case sensitive
            expected: nil
        ),
        FlagsToSetFixture(
            input: "",
            expected: nil
        ),
        FlagsToSetFixture(
            input: "unseen",  // not a valid flag
            expected: nil
        ),
        FlagsToSetFixture(
            input: "flag",  // partial match
            expected: nil
        ),
    ])
    static func flagsToUnset(
        fixture: FlagsToSetFixture
    ) throws {
        let parsed = MessageFlag(argument: fixture.input)
        if let expected = fixture.expected {
            let p = try #require(parsed)
            #expect(p.flagsToUnset == expected)
        } else {
            #expect(parsed == nil)
        }
    }

    struct FlagsToSearchFixture: Hashable, CustomTestStringConvertible {
        var flag: MessageFlag
        var expectedSet: Set<NIOIMAP.Flag>
        var expectedNotSet: Set<NIOIMAP.Flag>

        var testDescription: String { flag.rawValue }
    }

    @Test(arguments: [
        // Standard IMAP flags (set the flag, notSet is empty)
        FlagsToSearchFixture(
            flag: .answered,
            expectedSet: [.answered],
            expectedNotSet: []
        ),
        FlagsToSearchFixture(
            flag: .flagged,
            expectedSet: [.flagged],
            expectedNotSet: []
        ),
        FlagsToSearchFixture(
            flag: .deleted,
            expectedSet: [.deleted],
            expectedNotSet: []
        ),
        FlagsToSearchFixture(
            flag: .seen,
            expectedSet: [.seen],
            expectedNotSet: []
        ),
        FlagsToSearchFixture(
            flag: .draft,
            expectedSet: [.draft],
            expectedNotSet: []
        ),

        // Color flags (set flagged + specific bits, notSet contains other bits)
        FlagsToSearchFixture(
            flag: .red,
            expectedSet: [.flagged],
            expectedNotSet: [.mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSearchFixture(
            flag: .orange,
            expectedSet: [.flagged, .mailFlagBit0],
            expectedNotSet: [.mailFlagBit1, .mailFlagBit2]
        ),
        FlagsToSearchFixture(
            flag: .yellow,
            expectedSet: [.flagged, .mailFlagBit1],
            expectedNotSet: [.mailFlagBit0, .mailFlagBit2]
        ),
        FlagsToSearchFixture(
            flag: .green,
            expectedSet: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2],
            expectedNotSet: []
        ),
        FlagsToSearchFixture(
            flag: .blue,
            expectedSet: [.flagged, .mailFlagBit2],
            expectedNotSet: [.mailFlagBit0, .mailFlagBit1]
        ),
        FlagsToSearchFixture(
            flag: .purple,
            expectedSet: [.flagged, .mailFlagBit0, .mailFlagBit2],
            expectedNotSet: [.mailFlagBit1]
        ),
        FlagsToSearchFixture(
            flag: .gray,
            expectedSet: [.flagged, .mailFlagBit1, .mailFlagBit2],
            expectedNotSet: [.mailFlagBit0]
        ),
    ])
    static func flagsToSearch(
        fixture: FlagsToSearchFixture
    ) throws {
        let result = fixture.flag.flagsToSearch
        #expect(result.set == fixture.expectedSet)
        #expect(result.notSet == fixture.expectedNotSet)
    }
}
