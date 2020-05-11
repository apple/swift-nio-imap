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

/// IMAPv4 `esearch-response`
public struct ESearchResponse: Equatable {
    public var correlator: ByteBuffer?
    public var uid: Bool
    public var returnData: [SearchReturnData]

    public init(correlator: ByteBuffer? = nil, uid: Bool, returnData: [SearchReturnData]) {
        self.correlator = correlator
        self.uid = uid
        self.returnData = returnData
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeESearchResponse(_ response: ESearchResponse) -> Int {
        self.writeString("ESEARCH") +
            self.writeIfExists(response.correlator) { (correlator) -> Int in
                self.writeSearchCorrelator(correlator)
            } +
            self.writeIfTrue(response.uid) {
                self.writeString(" UID")
            } +
            self.writeIfTrue(response.returnData.count > 0) {
                self.writeSpace()
            } +
            self.writeArray(response.returnData, parenthesis: false) { (data, self) in
                self.writeSearchReturnData(data)
            }
    }
}
