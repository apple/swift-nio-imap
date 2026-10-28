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

/// Number of messages per batch when partitioning `FETCH` / `SEARCH` requests.
struct BatchSize: Hashable, Sendable {
    /// Always positive.
    let count: Int

    init?(_ count: Int) {
        guard 0 < count else { return nil }
        self.count = count
    }
}

extension BatchSize {
    /// Floor for the batch size.
    ///
    /// When a server advertises a smaller `MESSAGELIMIT`, we still use this floor as
    /// the batch size — the server's `MESSAGELIMIT` caps how many results may be
    /// returned in a single response, not how many UIDs we may include in a request.
    static let minimum: BatchSize = 1_000

    /// `max(minimum, serverMessageLimit)`.
    ///
    /// Falls back to `minimum` if the server does not advertise `MESSAGELIMIT` (RFC 9738).
    init(capabilities: [Capability]) {
        guard
            let value = capabilities.first(where: { $0.name == "MESSAGELIMIT" })?.value,
            let parsed = UInt32(value),
            let limit = Int(exactly: parsed).flatMap(BatchSize.init)
        else {
            self = .minimum
            return
        }
        self = max(.minimum, limit)
    }
}

extension BatchSize {
    /// Sequence numbers covered by the batch at `index`, for RFC 9394 `PARTIAL` ranges.
    ///
    /// Counted from the end of the mailbox (1 = newest).
    /// E.g. for a size of 1,000: index 0 → `1...1000`, index 1 → `1001...2000`.
    /// The end is clamped to `SequenceNumber.max`.
    func partialRange(batch index: Int) -> ClosedRange<SequenceNumber> {
        let startOffset = Int64(index) * Int64(count)
        let endOffset = Swift.min(
            startOffset + Int64(count) - 1,
            SequenceNumber.min.distance(to: .max)
        )
        return SequenceNumber.min.advanced(by: startOffset)...SequenceNumber.min.advanced(by: endOffset)
    }
}

extension BatchSize: Comparable {
    static func < (lhs: BatchSize, rhs: BatchSize) -> Bool {
        lhs.count < rhs.count
    }
}

extension BatchSize: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        guard let size = BatchSize(value) else { preconditionFailure("BatchSize must be positive: \(value)") }
        self = size
    }
}

extension BatchSize: CustomStringConvertible {
    var description: String { "\(count)" }
}
