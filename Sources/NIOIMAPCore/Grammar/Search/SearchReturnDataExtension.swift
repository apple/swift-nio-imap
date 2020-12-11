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

/// Implemented as a catch all to support any data that may be defined in future RFCs.
public struct SearchReturnDataExtension: Equatable {
    /// The name of the data field.
    public var modifierName: String

    /// The data value.
    public var returnValue: ParameterValue

    /// Creates a new `SearchReturnDataExtension`.
    /// - parameter modifierName: The name of the data field.
    /// - parameter returnValue: The data value.
    public init(modifierName: String, returnValue: ParameterValue) {
        self.modifierName = modifierName
        self.returnValue = returnValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnDataExtension(_ data: SearchReturnDataExtension) -> Int {
        self.writeString(data.modifierName) +
            self.writeSpace() +
            self.writeParameterValue(data.returnValue)
    }
}
