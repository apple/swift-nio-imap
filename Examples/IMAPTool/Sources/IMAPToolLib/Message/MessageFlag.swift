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

import ArgumentParser
import NIOIMAP

enum MessageFlag: String, Hashable, CaseIterable, ExpressibleByArgument {
    /// `\Answered`
    case answered
    /// `\Flagged`
    case flagged
    /// `\Deleted`
    case deleted
    /// `\Seen`
    case seen
    /// `\Draft`
    case draft

    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray
}

extension MessageFlag {
    var flagsToSearch: FlagsToSearch {
        switch self {
        case .answered, .flagged, .deleted, .seen, .draft:
            return FlagsToSearch(
                set: flagsToSet,
                notSet: []
            )
        case .red, .orange, .yellow, .green, .blue, .purple, .gray:
            let allColorBits: Set<NIOIMAP.Flag> = [.mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
            return FlagsToSearch(
                set: flagsToSet,
                notSet: allColorBits.subtracting(flagsToSet)
            )
        }
    }

    struct FlagsToSearch: Sendable, Hashable {
        var set: Set<NIOIMAP.Flag>
        var notSet: Set<NIOIMAP.Flag>
    }
}

extension MessageFlag {
    var flagsToSet: Set<NIOIMAP.Flag> {
        switch self {
        case .answered: [.answered]
        case .flagged: [.flagged]
        case .deleted: [.deleted]
        case .seen: [.seen]
        case .draft: [.draft]
        case .red: [.flagged]
        case .orange: [.flagged, .mailFlagBit0]
        case .yellow: [.flagged, .mailFlagBit1]
        case .green: [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        case .blue: [.flagged, .mailFlagBit2]
        case .purple: [.flagged, .mailFlagBit0, .mailFlagBit2]
        case .gray: [.flagged, .mailFlagBit1, .mailFlagBit2]
        }
    }

    var flagsToUnset: Set<NIOIMAP.Flag> {
        switch self {
        case .answered: [.answered]
        case .flagged: [.flagged]
        case .deleted: [.deleted]
        case .seen: [.seen]
        case .draft: [.draft]
        case .red,
            .orange,
            .yellow,
            .green,
            .blue,
            .purple,
            .gray:
            [.flagged, .mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
        }
    }
}

extension NIOIMAP.Flag {
    static var mailFlagBit0: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit0") }
    static var mailFlagBit1: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit1") }
    static var mailFlagBit2: NIOIMAP.Flag { NIOIMAP.Flag("$MailFlagBit2") }
}
