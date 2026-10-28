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
import NIOIMAP
import Testing

@Suite("Stable mailbox-name comparison")
private enum StableMailboxNameSortingTests {
    struct CompareFixture: Sendable, CustomTestStringConvertible {
        var lhs: MailboxName
        var rhs: MailboxName
        var expected: Bool
        var note: String

        var testDescription: String { note }
    }

    @Test(arguments: [
        // INBOX always comes before any non-INBOX mailbox.
        CompareFixture(
            lhs: .inbox,
            rhs: name("Drafts"),
            expected: true,
            note: "INBOX < Drafts"
        ),
        CompareFixture(
            lhs: name("Drafts"),
            rhs: .inbox,
            expected: false,
            note: "Drafts !< INBOX"
        ),
        CompareFixture(
            lhs: .inbox,
            rhs: name("AAA"),
            expected: true,
            note: "INBOX < AAA (even though byte-wise A < I)"
        ),
        // INBOX is case-insensitive — `MailboxName` normalizes any spelling to "INBOX".
        CompareFixture(
            lhs: name("inbox"),
            rhs: name("Drafts"),
            expected: true,
            note: "lowercase inbox normalized to INBOX, still wins"
        ),

        // Two INBOXes are equivalent.
        CompareFixture(
            lhs: .inbox,
            rhs: .inbox,
            expected: false,
            note: "INBOX !< INBOX"
        ),

        // Byte-wise ordering of non-INBOX names.
        CompareFixture(
            lhs: name("Drafts"),
            rhs: name("Sent"),
            expected: true,
            note: "Drafts < Sent"
        ),
        CompareFixture(
            lhs: name("Sent"),
            rhs: name("Drafts"),
            expected: false,
            note: "Sent !< Drafts"
        ),

        // Byte-exact comparison: uppercase precedes lowercase in ASCII.
        CompareFixture(
            lhs: name("ABC"),
            rhs: name("abc"),
            expected: true,
            note: "ABC < abc (byte-exact)"
        ),

        // Length tiebreak: when one is a prefix of the other, the shorter wins.
        CompareFixture(
            lhs: name("Foo"),
            rhs: name("Foobar"),
            expected: true,
            note: "prefix < longer"
        ),
        CompareFixture(
            lhs: name("Foobar"),
            rhs: name("Foo"),
            expected: false,
            note: "longer !< prefix"
        ),

        // Equal names compare false (strict less-than).
        CompareFixture(
            lhs: name("Drafts"),
            rhs: name("Drafts"),
            expected: false,
            note: "Drafts !< Drafts"
        ),
    ])
    static func compare(fixture: CompareFixture) {
        #expect(stableCompare(fixture.lhs, fixture.rhs) == fixture.expected)
    }

    /// Higher-level check: `stableCompare` is suitable as a `<` predicate for
    /// `sorted(by:)` — INBOX leads, the rest follow in byte order.
    @Test
    static func sortsAsExpected() {
        let input: [MailboxName] = [
            name("Sent"),
            name("Drafts"),
            .inbox,
            name("Archive"),
            name("Trash"),
        ]
        let sorted = input.sorted(by: stableCompare)
        let expected: [MailboxName] = [
            .inbox,
            name("Archive"),
            name("Drafts"),
            name("Sent"),
            name("Trash"),
        ]
        #expect(sorted == expected)
    }

    /// `MailboxName` stores raw bytes (modified UTF-7 on the wire), so the
    /// comparison is byte-exact and unaware of encoding. Names that decode to
    /// the same display string but differ in their byte representation are
    /// treated as distinct, ordered by their bytes.
    @Test
    static func comparesRawBytes() {
        let a = MailboxName([0x41, 0x42])  // "AB"
        let b = MailboxName([0x41, 0x42, 0x43])  // "ABC"
        #expect(stableCompare(a, b))
        #expect(!stableCompare(b, a))
    }
}

private func name(_ s: String) -> MailboxName {
    MailboxName(Array(s.utf8))
}
