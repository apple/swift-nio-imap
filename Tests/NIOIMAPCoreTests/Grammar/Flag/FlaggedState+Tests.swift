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

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("FlaggedState")
struct FlaggedStateTests {
    static let bit0 = Flag.keyword(.colorBit0)
    static let bit1 = Flag.keyword(.colorBit1)
    static let bit2 = Flag.keyword(.colorBit2)

    @Test(
        "flagged(_:).flagChanges produces the RFC 9979 set/clear flags",
        arguments: [
            (FlaggedState.Color.red, Set([Flag.flagged]), Set([Self.bit0, Self.bit1, Self.bit2])),
            (.orange, [.flagged, Self.bit0], [Self.bit1, Self.bit2]),
            (.yellow, [.flagged, Self.bit1], [Self.bit0, Self.bit2]),
            (.green, [.flagged, Self.bit0, Self.bit1], [Self.bit2]),
            (.blue, [.flagged, Self.bit2], [Self.bit0, Self.bit1]),
            (.purple, [.flagged, Self.bit0, Self.bit2], [Self.bit1]),
            (.gray, [.flagged, Self.bit1, Self.bit2], [Self.bit0]),
        ] as [(FlaggedState.Color, Set<Flag>, Set<Flag>)]
    )
    func flaggedUpdate(_ color: FlaggedState.Color, _ expectedSet: Set<Flag>, _ expectedClear: Set<Flag>) {
        let changes = FlaggedState.flagged(color).flagChanges
        #expect(changes.flagsToSet == expectedSet)
        #expect(changes.flagsToClear == expectedClear)
    }

    @Test(
        "flagged(_:).flagChanges always sets \\Flagged, so a color is never set without it",
        arguments: FlaggedState.Color.allCases
    )
    func flaggedUpdateAlwaysFlags(_ color: FlaggedState.Color) {
        #expect(FlaggedState.flagged(color).flagChanges.flagsToSet.contains(.flagged))
    }

    @Test("unflagged.flagChanges unflags and clears all color bits")
    func unflag() {
        let changes = FlaggedState.unflagged.flagChanges
        #expect(changes.flagsToSet == [])
        #expect(changes.flagsToClear == [.flagged, Self.bit0, Self.bit1, Self.bit2])
    }

    @Test("Color.allCases is the seven RFC colors")
    func allCasesAreTheSevenColors() {
        #expect(FlaggedState.Color.allCases == [.red, .orange, .yellow, .green, .blue, .purple, .gray])
    }

    @Test(
        "color reports the color for a flagged state and nil when unflagged",
        arguments: FlaggedState.Color.allCases
    )
    func color(_ color: FlaggedState.Color) {
        #expect(FlaggedState.flagged(color).color == color)
        #expect(FlaggedState.unflagged.color == nil)
    }

    @Test(
        "flagged(_:).flagChanges round-trips through FlaggedState(flags:)",
        arguments: FlaggedState.Color.allCases
    )
    func roundTrip(_ color: FlaggedState.Color) {
        let changes = FlaggedState.flagged(color).flagChanges
        #expect(FlaggedState(flags: changes.flagsToSet) == .flagged(color))
    }

    /// Applies `changes` to `starting` the way two `STORE` commands would:
    /// remove `flagsToClear`, then add `flagsToSet`.
    static func apply(_ changes: FlaggedState.Update, to starting: Set<Flag>) -> Set<Flag> {
        starting.subtracting(changes.flagsToClear).union(changes.flagsToSet)
    }

    @Test(
        "flagged(_:).flagChanges scrubs stray color bits when applied to an already-colored message",
        arguments: FlaggedState.Color.allCases
    )
    func flagChangesClearsStrayBits(_ color: FlaggedState.Color) {
        // Start from a message that already carries every color bit (the `111`
        // pattern) plus an unrelated flag. Applying `flagChanges` must leave
        // exactly the requested color, exercising `flagsToClear`.
        let starting: Set<Flag> = [.flagged, Self.bit0, Self.bit1, Self.bit2, .seen]
        let result = Self.apply(FlaggedState.flagged(color).flagChanges, to: starting)
        #expect(FlaggedState(flags: result) == .flagged(color))
        // Unrelated flags are preserved.
        #expect(result.contains(.seen))
    }

    @Test(
        "unflagged.flagChanges clears \\Flagged and every color bit when applied to a flagged message",
        arguments: FlaggedState.Color.allCases
    )
    func unflagClearsEverything(_ color: FlaggedState.Color) {
        let starting = Self.apply(FlaggedState.flagged(color).flagChanges, to: [.seen])
        let result = Self.apply(FlaggedState.unflagged.flagChanges, to: starting)
        #expect(FlaggedState(flags: result) == .unflagged)
        #expect(!result.contains(.flagged))
        #expect(result.isDisjoint(with: [Self.bit0, Self.bit1, Self.bit2]))
        #expect(result.contains(.seen))
    }

    @Test(
        "FlaggedState(flags:) decodes the RFC 9979 bit patterns",
        arguments: [
            (Set([Flag.flagged]), FlaggedState.flagged(.red)),
            ([.flagged, Self.bit0], .flagged(.orange)),
            ([.flagged, Self.bit1], .flagged(.yellow)),
            ([.flagged, Self.bit0, Self.bit1], .flagged(.green)),
            ([.flagged, Self.bit2], .flagged(.blue)),
            ([.flagged, Self.bit0, Self.bit2], .flagged(.purple)),
            ([.flagged, Self.bit1, Self.bit2], .flagged(.gray)),
            // Color bits are additive with unrelated flags:
            ([.flagged, Self.bit0, .seen, .answered], .flagged(.orange)),
        ] as [(Set<Flag>, FlaggedState)]
    )
    func decode(_ flags: Set<Flag>, _ expected: FlaggedState) {
        #expect(FlaggedState(flags: flags) == expected)
    }

    @Test("FlaggedState(flags:) maps the unassigned 111 pattern to .red by default")
    func decodeUnassignedDefaultsToRed() {
        #expect(FlaggedState(flags: [.flagged, Self.bit0, Self.bit1, Self.bit2]) == .flagged(.red))
    }

    @Test("FlaggedState(flags:mapUnassignedTo:) maps the unassigned 111 pattern to a custom color")
    func decodeUnassignedCustomMapping() {
        #expect(
            FlaggedState(flags: [.flagged, Self.bit0, Self.bit1, Self.bit2], mapUnassignedTo: .green)
                == .flagged(.green)
        )
    }

    @Test(
        "FlaggedState(flags:) is unflagged whenever \\Flagged is absent",
        arguments: [
            // Not flagged -> unflagged, even if color bits are present.
            Set<Flag>([]),
            [Self.bit0],
            [Self.bit0, Self.bit1, Self.bit2],
            [.seen, Self.bit1],
        ]
    )
    func decodeUnflagged(_ flags: Set<Flag>) {
        #expect(FlaggedState(flags: flags) == .unflagged)
    }

    @Test("FlaggedState(flags:) compares flags case-insensitively")
    func decodeCaseInsensitive() {
        let flags: [Flag] = [.extension("\\FLAGGED"), .keyword(Flag.Keyword("$mailflagbit1")!)]
        #expect(FlaggedState(flags: flags) == .flagged(.yellow))
    }
}

@Suite("RawFlaggedState")
struct RawFlaggedStateTests {
    static let bit0 = Flag.keyword(.colorBit0)
    static let bit1 = Flag.keyword(.colorBit1)
    static let bit2 = Flag.keyword(.colorBit2)

    @Test(
        "init(flags:) decodes the RFC 9979 bit patterns, preserving the unassigned 111",
        arguments: [
            (Set([Flag.flagged]), RawFlaggedState.flagged(.red)),
            ([.flagged, Self.bit0], .flagged(.orange)),
            ([.flagged, Self.bit1], .flagged(.yellow)),
            ([.flagged, Self.bit0, Self.bit1], .flagged(.green)),
            ([.flagged, Self.bit2], .flagged(.blue)),
            ([.flagged, Self.bit0, Self.bit2], .flagged(.purple)),
            ([.flagged, Self.bit1, Self.bit2], .flagged(.gray)),
            // The RFC-unassigned `111` is preserved as the distinct case.
            ([.flagged, Self.bit0, Self.bit1, Self.bit2], .flaggedUnassigned),
        ] as [(Set<Flag>, RawFlaggedState)]
    )
    func decode(_ flags: Set<Flag>, _ expected: RawFlaggedState) {
        #expect(RawFlaggedState(flags: flags) == expected)
    }

    @Test(
        "init(flags:) is unflagged whenever \\Flagged is absent",
        arguments: [
            Set<Flag>([]),
            [Self.bit0],
            [Self.bit0, Self.bit1, Self.bit2],
        ]
    )
    func decodeUnflagged(_ flags: Set<Flag>) {
        #expect(RawFlaggedState(flags: flags) == .unflagged)
    }

    @Test("flaggedUnassigned.flagChanges sets all three color bits and clears nothing")
    func unassignedUpdate() {
        let changes = RawFlaggedState.flaggedUnassigned.flagChanges
        #expect(changes.flagsToSet == [.flagged, Self.bit0, Self.bit1, Self.bit2])
        #expect(changes.flagsToClear == [])
    }

    @Test(
        "flagChanges round-trips through init(flags:) for every flagged case",
        arguments: [
            RawFlaggedState.flagged(.red), .flagged(.orange), .flagged(.yellow), .flagged(.green),
            .flagged(.blue), .flagged(.purple), .flagged(.gray),
            .flaggedUnassigned,
        ] as [RawFlaggedState]
    )
    func roundTrip(_ state: RawFlaggedState) {
        #expect(RawFlaggedState(flags: state.flagChanges.flagsToSet) == state)
    }

    @Test(
        "flagChanges scrubs stray color bits when applied to an already-colored message",
        arguments: [
            RawFlaggedState.flagged(.red), .flagged(.orange), .flagged(.yellow), .flagged(.green),
            .flagged(.blue), .flagged(.purple), .flagged(.gray),
            .flaggedUnassigned,
        ] as [RawFlaggedState]
    )
    func flagChangesClearsStrayBits(_ state: RawFlaggedState) {
        // Start from a message carrying every color bit plus an unrelated flag,
        // then apply `flagChanges` removing `flagsToClear` before adding `flagsToSet`.
        let starting: Set<Flag> = [.flagged, Self.bit0, Self.bit1, Self.bit2, .seen]
        let result = starting.subtracting(state.flagChanges.flagsToClear).union(state.flagChanges.flagsToSet)
        #expect(RawFlaggedState(flags: result) == state)
        #expect(result.contains(.seen))
    }

    @Test("unflagged.flagChanges unflags and clears all color bits")
    func unflag() {
        let changes = RawFlaggedState.unflagged.flagChanges
        #expect(changes.flagsToSet == [])
        #expect(changes.flagsToClear == [.flagged, Self.bit0, Self.bit1, Self.bit2])
    }

    @Test(
        "FlaggedState(_:mapUnassignedTo:) folds .flaggedUnassigned into the given color and carries the rest over",
        arguments: FlaggedState.Color.allCases
    )
    func collapseToFlaggedState(_ color: FlaggedState.Color) {
        #expect(FlaggedState(RawFlaggedState.flaggedUnassigned, mapUnassignedTo: color) == .flagged(color))
        #expect(FlaggedState(RawFlaggedState.flagged(color), mapUnassignedTo: .green) == .flagged(color))
        #expect(FlaggedState(RawFlaggedState.unflagged, mapUnassignedTo: .green) == .unflagged)
    }

    @Test("FlaggedState(_:) defaults .flaggedUnassigned to .red")
    func collapseDefaultsToRed() {
        #expect(FlaggedState(RawFlaggedState.flaggedUnassigned) == .flagged(.red))
    }

    @Test(
        "init(_:) losslessly lifts a FlaggedState",
        arguments: [
            (FlaggedState.unflagged, RawFlaggedState.unflagged),
            (.flagged(.red), .flagged(.red)),
            (.flagged(.gray), .flagged(.gray)),
        ] as [(FlaggedState, RawFlaggedState)]
    )
    func liftFromFlaggedState(_ state: FlaggedState, _ expected: RawFlaggedState) {
        #expect(RawFlaggedState(state) == expected)
    }
}
