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

/// Sent from a server in response to an extended search.
public struct UIDBatchesResponse: Hashable, Sendable {
    /// The tag of the command that this search result is a response to.
    public var correlator: SearchCorrelator

    /// Data returned from the search.
    public var batches: [UIDRange]

    /// Creates a new `UIDBatchesResponse`.
    /// - parameter correlator: Identifies the command that resulted in this response.
    /// - parameter batches: The UID batches returned by the command.
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
