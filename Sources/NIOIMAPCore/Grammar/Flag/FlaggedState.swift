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

/// The flagged state of a message: either ``unflagged``, or ``flagged(_:)`` with
/// a ``Color``.
///
/// IMAP's `\Flagged` system flag ([RFC 9051](https://www.rfc-editor.org/rfc/rfc9051.html))
/// marks a message as needing attention.
/// [RFC 9979](https://www.rfc-editor.org/rfc/rfc9979.html) extends this: a
/// flagged message's mark may be shown in one of seven colors, encoded as a
/// 3-bit mask across the ``Flag/Keyword/colorBit0``, ``Flag/Keyword/colorBit1``,
/// and ``Flag/Keyword/colorBit2`` keywords (see ``Color``).
///
/// `FlaggedState` models the message-level concept that ``Flag`` does not: a
/// single ``Flag`` is one keyword on the wire, whereas a `FlaggedState` value
/// combines the `\Flagged` mark and its color into the one thing a user actually
/// sets.
///
/// Decode a message's current state with ``init(flags:mapUnassignedTo:)``, and
/// turn a desired state into the flags to store with ``flagChanges``:
///
/// ```swift
/// // What state is the message in?
/// let state = FlaggedState(flags: message.flags)   // .unflagged, or .flagged(.red), ...
///
/// // Flag a message green, or remove its mark entirely:
/// let toGreen = FlaggedState.flagged(.green).flagChanges
/// let toClear = FlaggedState.unflagged.flagChanges
/// ```
///
/// A color is only meaningful while `\Flagged` is set, and this type keeps the
/// two consistent: ``init(flags:mapUnassignedTo:)`` reports an unflagged message
/// as ``unflagged`` regardless of any color bits present, and ``flagChanges`` never
/// sets color bits without also setting `\Flagged`. The invalid "colored but not
/// flagged" state therefore can't arise through this API.
///
/// Through this API a flagged message *always* carries a color: the bit pattern
/// with no color bits set is ``Color/red``, so ``Color/red`` is equivalent to
/// "flagged, but no color keywords present" — including messages flagged by
/// clients that predate or ignore RFC 9979. A client that does not want to deal
/// with colors at all can simply set ``Flag/flagged`` directly instead of using
/// `FlaggedState`.
///
/// RFC 9979 leaves one bit combination (`111`) unassigned. `FlaggedState` folds
/// it into a real color so that callers only ever deal with the seven colors.
/// The rare client that needs to preserve those bits verbatim across a decode /
/// re-encode should use ``RawFlaggedState`` instead.
///
/// - SeeAlso: ``Flag``
/// - SeeAlso: ``RawFlaggedState``
/// - SeeAlso: [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3)
public enum FlaggedState: Hashable, Sendable {
    /// The message is not flagged, and therefore has no color.
    case unflagged

    /// The message is flagged, and its mark has the given ``Color``.
    case flagged(Color)

    /// One of the seven flag colors defined in
    /// [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3).
    ///
    /// Each color is a 3-bit mask across the ``Flag/Keyword/colorBit0``,
    /// ``Flag/Keyword/colorBit1``, and ``Flag/Keyword/colorBit2`` keywords:
    ///
    /// | Color      | bit 0 | bit 1 | bit 2 |
    /// | ---------- | ----- | ----- | ----- |
    /// | ``red``    | 0     | 0     | 0     |
    /// | ``orange`` | 1     | 0     | 0     |
    /// | ``yellow`` | 0     | 1     | 0     |
    /// | ``green``  | 1     | 1     | 0     |
    /// | ``blue``   | 0     | 0     | 1     |
    /// | ``purple`` | 1     | 0     | 1     |
    /// | ``gray``   | 0     | 1     | 1     |
    ///
    /// RFC 9979 assigns no color to the eighth combination, `111`. It does not
    /// appear here: ``FlaggedState`` and its ``FlaggedState/init(flags:mapUnassignedTo:)``
    /// fold it into a real color. To preserve that pattern verbatim, use
    /// ``RawFlaggedState`` and its ``RawFlaggedState/flaggedUnassigned`` case.
    public enum Color: Sendable, Hashable, CaseIterable {
        /// No color bits set.
        case red
        /// ``Flag/Keyword/colorBit0`` set.
        case orange
        /// ``Flag/Keyword/colorBit1`` set.
        case yellow
        /// ``Flag/Keyword/colorBit0`` and ``Flag/Keyword/colorBit1`` set.
        case green
        /// ``Flag/Keyword/colorBit2`` set.
        case blue
        /// ``Flag/Keyword/colorBit0`` and ``Flag/Keyword/colorBit2`` set.
        case purple
        /// ``Flag/Keyword/colorBit1`` and ``Flag/Keyword/colorBit2`` set.
        case gray
    }

    /// The IMAP flags that must be set and cleared on a message to put it into a
    /// given ``FlaggedState`` (or ``RawFlaggedState``).
    ///
    /// Obtain an `Update` from ``FlaggedState/flagChanges`` or ``RawFlaggedState/flagChanges``.
    ///
    /// Apply an `Update` with two `STORE` commands. Issue `STORE -FLAGS
    /// (flagsToClear)` *before* `STORE +FLAGS (flagsToSet)`: clearing first means
    /// the message transits through a valid intermediate color rather than the
    /// unassigned `111` combination. (The two commands are not atomic, so another
    /// client may still observe the intermediate state.) Skip either command when
    /// its set ``Swift/Set/isEmpty`` is `true` — for example, ``FlaggedState/unflagged``
    /// produces an empty `flagsToSet` — since a `STORE` with an empty flag list is
    /// a wasted round-trip. Only the ``FlaggedState/unflagged`` and
    /// ``RawFlaggedState/unflagged`` states ever produce an empty side; every
    /// `flagged` state has a non-empty `flagsToSet` (it always includes `\Flagged`)
    /// and, except ``RawFlaggedState/flaggedUnassigned``, a non-empty `flagsToClear`.
    ///
    /// Two separate `+FLAGS`/`-FLAGS` commands are used, rather than a single
    /// `STORE FLAGS` that replaces the whole flag list atomically, precisely so
    /// that unrelated keywords on the message (such as `\Seen` or `$Junk`) are
    /// preserved.
    ///
    /// The two operations together leave the message in the requested state
    /// regardless of its prior flags, so there is no need to read the message's
    /// current flags first.
    public struct Update: Hashable, Sendable {
        /// The flags that must be present (`STORE +FLAGS`).
        public var flagsToSet: Set<Flag>

        /// The flags that must be absent (`STORE -FLAGS`).
        public var flagsToClear: Set<Flag>

        /// Creates a new `Update`.
        /// - parameter flagsToSet: The flags that must be present.
        /// - parameter flagsToClear: The flags that must be absent.
        public init(flagsToSet: Set<Flag>, flagsToClear: Set<Flag>) {
            self.flagsToSet = flagsToSet
            self.flagsToClear = flagsToClear
        }
    }

    /// The ``Color`` of the mark when the message is ``flagged(_:)``, or `nil`
    /// when it is ``unflagged``.
    public var color: Color? {
        switch self {
        case .unflagged: nil
        case .flagged(let color): color
        }
    }

    /// The flags to set and clear to put a message into this state.
    ///
    /// For a ``flagged(_:)`` state the returned ``Update`` always sets `\Flagged`
    /// alongside the color bits and clears the color bits that don't belong to
    /// the color. Setting `\Flagged` together with the color bits satisfies
    /// [RFC 9979 Section 3.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-3.2),
    /// which requires that color flags never be set unless `\Flagged` is also
    /// set, so applying the update can never leave a message with color bits but
    /// no `\Flagged` flag. For ``unflagged`` it clears `\Flagged` and all three
    /// color bits — also required by Section 3.2 — and its ``Update/flagsToSet``
    /// is empty.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let changes = FlaggedState.flagged(.green).flagChanges
    /// // changes.flagsToSet   == [\Flagged, $MailFlagBit0, $MailFlagBit1]
    /// // changes.flagsToClear == [$MailFlagBit2]
    /// ```
    public var flagChanges: Update {
        switch self {
        case .unflagged: .unflagged
        case .flagged(let color): .flagged(withColorBits: color.colorBits)
        }
    }

    /// Reads a message's flagged state from its flags.
    ///
    /// Returns ``unflagged`` when ``Flag/flagged`` is absent — even if color bits
    /// are present — since a color is only meaningful on a flagged message.
    /// Otherwise returns ``flagged(_:)`` with the decoded ``Color``.
    ///
    /// RFC 9979 leaves the `111` bit combination unassigned and does not define
    /// how it should be presented. This initializer reports it as
    /// `mapUnassignedTo` — defaulting to ``Color/red``, but you may pass any
    /// color — so the result is always one of the seven colors. The red default
    /// is the library's choice, not an RFC requirement. Use ``RawFlaggedState``
    /// if you need to tell the `111` pattern apart from red and preserve it
    /// across a re-encode.
    ///
    /// - parameter flags: The message's flags. Flag comparison is
    ///     case-insensitive.
    /// - parameter mapUnassignedTo: The color to report for the RFC-unassigned
    ///     `111` bit combination. Defaults to ``Color/red``.
    public init(flags: some Sequence<Flag>, mapUnassignedTo: Color = .red) {
        self = FlaggedState(RawFlaggedState(flags: flags), mapUnassignedTo: mapUnassignedTo)
    }

    /// Collapses a ``RawFlaggedState`` to a `FlaggedState`, mapping its
    /// ``RawFlaggedState/flaggedUnassigned`` case to a real ``Color``.
    ///
    /// ``RawFlaggedState/unflagged`` and ``RawFlaggedState/flagged(_:)`` carry
    /// over unchanged; ``RawFlaggedState/flaggedUnassigned`` becomes
    /// ``flagged(_:)`` with `mapUnassignedTo`, which defaults to ``Color/red``
    /// (see ``init(flags:mapUnassignedTo:)`` for why red is the default).
    ///
    /// This is the lossy inverse of ``RawFlaggedState/init(_:)``.
    ///
    /// - parameter raw: The state to collapse.
    /// - parameter mapUnassignedTo: The color to map
    ///     ``RawFlaggedState/flaggedUnassigned`` to. Defaults to ``Color/red``.
    public init(_ raw: RawFlaggedState, mapUnassignedTo: Color = .red) {
        switch raw {
        case .unflagged: self = .unflagged
        case .flagged(let color): self = .flagged(color)
        case .flaggedUnassigned: self = .flagged(mapUnassignedTo)
        }
    }
}

/// The flagged state of a message, preserving RFC 9979's unassigned `111` bit
/// pattern verbatim.
///
/// Most library users should use ``FlaggedState`` instead.
///
/// This is a lossless variant of ``FlaggedState`` for the rare client that must
/// round-trip a message's flags without altering them. Where ``FlaggedState``
/// folds the RFC-unassigned `111` combination into a real ``FlaggedState/Color``,
/// `RawFlaggedState` keeps it as the distinct ``flaggedUnassigned`` case so that
/// decoding and re-encoding a message leaves its stored bits unchanged.
///
/// **Prefer ``FlaggedState``.** Reach for `RawFlaggedState` only when faithful
/// round-tripping matters; for everything else — presentation, setting a color,
/// clearing the mark — the seven-color ``FlaggedState`` is simpler and sufficient.
/// Collapse it to a ``FlaggedState`` at any time with
/// ``FlaggedState/init(_:mapUnassignedTo:)``.
///
/// - SeeAlso: ``FlaggedState``
/// - SeeAlso: [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3)
public enum RawFlaggedState: Hashable, Sendable {
    /// The message is not flagged, and therefore has no color.
    case unflagged

    /// The message is flagged, and its mark has the given ``FlaggedState/Color``.
    case flagged(FlaggedState.Color)

    /// The message is flagged and carries the RFC-unassigned `111` bit pattern
    /// (all three of ``Flag/Keyword/colorBit0``, ``Flag/Keyword/colorBit1``, and
    /// ``Flag/Keyword/colorBit2``).
    ///
    /// RFC 9979 assigns no color to this combination. The RFC does not define
    /// its appearance; map it to a real color for presentation with
    /// ``FlaggedState/init(_:mapUnassignedTo:)``
    /// (which defaults to ``FlaggedState/Color/red``). Its ``flagChanges`` writes the
    /// `111` pattern back out verbatim.
    case flaggedUnassigned

    /// The flags to set and clear to put a message into this state.
    ///
    /// Behaves like ``FlaggedState/flagChanges``, additionally handling
    /// ``flaggedUnassigned`` by setting `\Flagged` plus all three color bits and
    /// clearing nothing — writing the RFC-unassigned `111` pattern back verbatim.
    public var flagChanges: FlaggedState.Update {
        switch self {
        case .unflagged: .unflagged
        case .flagged(let color): .flagged(withColorBits: color.colorBits)
        case .flaggedUnassigned: .flagged(withColorBits: FlaggedState.Color.allColorBits)
        }
    }

    /// Reads a message's flagged state from its flags, preserving the unassigned
    /// `111` pattern.
    ///
    /// Returns ``unflagged`` when ``Flag/flagged`` is absent (even if color bits
    /// are present), ``flaggedUnassigned`` when all three color bits are set, and
    /// otherwise ``flagged(_:)`` with the decoded color.
    ///
    /// - parameter flags: The message's flags. Flag comparison is
    ///     case-insensitive.
    public init(flags: some Sequence<Flag>) {
        let flags = Set(flags)
        guard flags.contains(.flagged) else {
            self = .unflagged
            return
        }
        let bit0 = flags.contains(.keyword(.colorBit0))
        let bit1 = flags.contains(.keyword(.colorBit1))
        let bit2 = flags.contains(.keyword(.colorBit2))
        switch (bit0, bit1, bit2) {
        case (false, false, false): self = .flagged(.red)
        case (true, false, false): self = .flagged(.orange)
        case (false, true, false): self = .flagged(.yellow)
        case (true, true, false): self = .flagged(.green)
        case (false, false, true): self = .flagged(.blue)
        case (true, false, true): self = .flagged(.purple)
        case (false, true, true): self = .flagged(.gray)
        case (true, true, true): self = .flaggedUnassigned  // `111` is RFC-unassigned
        }
    }

    /// Creates a `RawFlaggedState` from a ``FlaggedState``. This is lossless,
    /// since every ``FlaggedState`` is also a `RawFlaggedState`.
    ///
    /// Use ``FlaggedState/init(_:mapUnassignedTo:)`` for the lossy inverse.
    public init(_ state: FlaggedState) {
        switch state {
        case .unflagged: self = .unflagged
        case .flagged(let color): self = .flagged(color)
        }
    }
}

extension FlaggedState.Update {
    /// The update that sets `\Flagged` plus exactly `colorBits`, and clears the
    /// color bits that aren't in `colorBits`.
    fileprivate static func flagged(withColorBits colorBits: Set<Flag>) -> Self {
        Self(
            flagsToSet: colorBits.union([.flagged]),
            flagsToClear: FlaggedState.Color.allColorBits.subtracting(colorBits)
        )
    }

    /// The update that clears `\Flagged` and all three color bits.
    fileprivate static let unflagged = Self(
        flagsToSet: [],
        flagsToClear: FlaggedState.Color.allColorBits.union([.flagged])
    )
}

extension FlaggedState.Color {
    /// The color bits that are set for this color, as ``Flag`` values.
    fileprivate var colorBits: Set<Flag> {
        switch self {
        case .red: []
        case .orange: [.keyword(.colorBit0)]
        case .yellow: [.keyword(.colorBit1)]
        case .green: [.keyword(.colorBit0), .keyword(.colorBit1)]
        case .blue: [.keyword(.colorBit2)]
        case .purple: [.keyword(.colorBit0), .keyword(.colorBit2)]
        case .gray: [.keyword(.colorBit1), .keyword(.colorBit2)]
        }
    }

    /// The three color-bit flags, as ``Flag`` values.
    fileprivate static let allColorBits: Set<Flag> = [
        .keyword(.colorBit0),
        .keyword(.colorBit1),
        .keyword(.colorBit2),
    ]
}
