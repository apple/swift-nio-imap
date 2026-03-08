//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// Response containing a batch of UIDs from an extended SEARCH command.
///
/// The UIDBATCHES return option allows servers to return search results as a series of batches
/// in descending order, which is useful for clients that want to process results incrementally.
/// Unlike the standard SEARCH response that returns a single space-separated list, UIDBATCHES
/// provides multiple response messages each containing a batch of UIDs, allowing memory-efficient
/// processing of large result sets.
///
/// Each UIDBATCHES response is correlated with a specific SEARCH command via a correlator (either
/// a tag or explicit identifier), allowing clients to match results to requests even with pipelined
/// commands.
///
/// ### Example
///
/// ```
/// C: A001 SEARCH RETURN (UIDBATCHES SORT (REVERSE DATE)) SINCE 1-Jan-2024
/// S: * UIDBATCHES 100 (999 1001:1010 2050)
/// S: * UIDBATCHES 100 (850:899 500:600)
/// S: A001 OK SEARCH completed
/// ```
///
/// Each `* UIDBATCHES ...` line is wrapped as this type. The first number (100) is the correlator
/// identifying the SEARCH request. The parenthesized content contains UID ranges in descending order.
/// Multiple UIDBATCHES responses can be sent for a single search command.
///
/// - SeeAlso: ``SearchCorrelator``, [UIDBATCHES Draft](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/)
public struct UIDBatchesResponse: Hashable, Sendable {
    /// The correlator linking this response to its search command.
    ///
    /// The correlator is either the tag of the original command (for tagged responses) or an
    /// explicit UID returned in response to a SEARCH command with the RETURN option. It allows
    /// clients to match multiple UIDBATCHES responses to the correct command, especially useful
    /// when commands are pipelined.
    ///
    /// - SeeAlso: ``SearchCorrelator``
    public var correlator: SearchCorrelator

    /// The batch of message UIDs returned from the search.
    ///
    /// Each batch contains message UIDs in descending order (highest first), represented as an
    /// array of UID ranges for efficient encoding and representation. Multiple batches may be
    /// sent for a single SEARCH command, allowing incremental result processing.
    ///
    /// - SeeAlso: ``UIDRange``
    public var batches: [UIDRange]

    /// Creates a new `UIDBatchesResponse`.
    /// - parameter correlator: The correlator identifying the search command.
    /// - parameter batches: The UID ranges returned from the search.
    public init(correlator: SearchCorrelator, batches: [UIDRange]) {
        self.correlator = correlator
        self.batches = batches
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDBatchesResponse(_ response: UIDBatchesResponse) -> Int {
        self.writeString(#"UIDBATCHES"#)
            + self.writeSearchCorrelator(response.correlator)
            + self.write(if: !response.batches.isEmpty) {
                self.writeString(" ")
                    + self.writeArray(response.batches, separator: ",", parenthesis: false) { range, buffer -> Int in
                        buffer.writeMessageIdentifierRange(range, descending: true)
                    }
            }
    }
}
