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

func stableCompare(
    _ lhs: MailboxName,
    _ rhs: MailboxName
) -> Bool {
    switch (lhs.isInbox, rhs.isInbox) {
    case (true, false): return true
    case (true, true): return false
    case (false, true): return false
    case (false, false): break
    }
    // Byte-wise ordering, with a shorter name sorting before a longer one that
    // shares its prefix — the same ordering `memcmp` plus a length tie-break gives.
    return lhs.bytes.lexicographicallyPrecedes(rhs.bytes)
}
