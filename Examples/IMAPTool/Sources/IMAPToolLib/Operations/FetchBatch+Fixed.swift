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

import NIOIMAP

// MARK: - Fixed `[UIDRange]` strategy
//
// Used when the caller passes `FetchQuery.uids(_)` to `makeBatches(...)` on a server
// without RFC 9394 `PARTIAL` support. The requested UIDs are split into ranges of
// at most `batchSize` UIDs each, preserving the UID ordering.

/// Splits the given UIDs into `UIDRange`s with at most `maximumCount` UIDs each.
func splitUIDsIntoRanges(
    uids: UIDSet,
    maximumCount: Int
) -> [UIDRange] {
    var ranges: [UIDRange] = []
    var remaining = uids
    while !remaining.isEmpty {
        guard
            let next = UIDSetNonEmpty(set: remaining.suffix(maximumCount))
        else { break }
        ranges.append(next.min()...next.max())
        remaining.subtract(UIDSet(next.min()...UID.max))
    }
    return ranges
}
