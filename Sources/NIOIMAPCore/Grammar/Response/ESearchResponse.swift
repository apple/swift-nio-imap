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
public struct ESearchResponse: Equatable {
    /// Identifies the search that resulted in this response.
    public var correlator: SearchCorrelator?

    /// `true` if this was a UID SEARCH, otherwise `false`.
    public var uid: Bool

    /// Data returned from the search.
    public var returnData: [SearchReturnData]

    /// Creates a new `ESearchResponse`.
    /// - parameter correlator: Identifies the search that resulted in this response. Defaults to `nil`.
    /// - parameter uid: `true` if this was a UID SEARCH, otherwise `false`.
    /// - parameter returnData: Data returned from the search.
    public init(correlator: SearchCorrelator? = nil, uid: Bool, returnData: [SearchReturnData]) {
        self.correlator = correlator
        self.uid = uid
        self.returnData = returnData
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeESearchResponse(_ response: ESearchResponse) -> Int {
        self.writeString("ESEARCH") +
            self.writeIfExists(response.correlator) { (correlator) -> Int in
                self.writeSearchCorrelator(correlator)
            } +
            self.write(if: response.uid) {
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
