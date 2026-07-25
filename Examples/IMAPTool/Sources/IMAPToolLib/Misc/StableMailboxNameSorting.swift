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
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

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
    return lhs.bytes.withUnsafeBytes { lhsBuffer -> Bool in
        rhs.bytes.withUnsafeBytes { rhsBuffer -> Bool in
            // Glibc’s `memcmp` takes non-optional pointers, and an empty buffer has
            // no base address. Two names can only compare equal by length in that case.
            guard
                let lhsAddress = lhsBuffer.baseAddress,
                let rhsAddress = rhsBuffer.baseAddress
            else { return lhsBuffer.count < rhsBuffer.count }
            let r = memcmp(
                lhsAddress,
                rhsAddress,
                Swift.min(lhsBuffer.count, rhsBuffer.count)
            )
            if r < 0 {
                return true
            } else if 0 < r {
                return false
            } else {
                return lhsBuffer.count < rhsBuffer.count
            }
        }
    }
}
