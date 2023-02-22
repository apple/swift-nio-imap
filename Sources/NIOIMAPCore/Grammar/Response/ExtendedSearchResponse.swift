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
public struct ExtendedSearchResponse: Hashable {
    /// Identifies the search that resulted in this response.
    public var correlator: SearchCorrelator?

    /// Is this a UID or a sequence number response?
    public var kind: Kind

    /// Data returned from the search.
    public var returnData: [SearchReturnData]

    /// Creates a new `ExtendedSearchResponse`.
    /// - parameter correlator: Identifies the search that resulted in this response. Defaults to `nil`.
    /// - parameter kind: Is this a response to `UID SEARCH` or `SEARCH`?
    /// - parameter returnData: Data returned from the search.
    public init(correlator: SearchCorrelator? = nil, kind: Kind, returnData: [SearchReturnData]) {
        self.correlator = correlator
        self.kind = kind
        self.returnData = returnData
    }
}

extension ExtendedSearchResponse {
    /// The kind of search response.
    ///
    /// Describes if the `UnknownMessageIdentifier` in the `returnData`’s `SearchReturnData` are `UID` or `SequenceNumber`.
    public enum Kind: Hashable {
        case sequenceNumber
        case uid
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchResponse(_ response: ExtendedSearchResponse) -> Int {
        self.writeString("ESEARCH") +
            self.writeIfExists(response.correlator) { (correlator) -> Int in
                self.writeSearchCorrelator(correlator)
            } +
            self.write(if: response.kind == .uid) {
                self.writeString(" UID")
            } +
            self.write(if: response.returnData.count > 0) {
                self.writeSpace()
            } +
            self.writeArray(response.returnData, parenthesis: false) { (data, self) in
                self.writeSearchReturnData(data)
            }
    }
}
