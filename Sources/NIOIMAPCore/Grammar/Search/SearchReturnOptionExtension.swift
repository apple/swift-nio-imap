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

/// Implemented as a catch all to support any options that may be defined in future RFCs.
public struct SearchReturnOptionExtension: Equatable {
    
    /// The search return option name.
    public var modifierName: String
    
    /// Any parameters that may go along with the option.
    public var params: ParameterValue?

    /// Creates a new `SearchReturnOptionExtension`.
    /// - parameter modifierName: The search return option name.
    /// - parameter params: Any parameters that may go along with the option. Defaults to `nil`.
    public init(modifierName: String, params: ParameterValue? = nil) {
        self.modifierName = modifierName
        self.params = params
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnOptionExtension(_ option: SearchReturnOptionExtension) -> Int {
        self.writeString(option.modifierName) +
            self.writeIfExists(option.params) { (params) -> Int in
                self.writeSpace() +
                    self.writeParameterValue(params)
            }
    }
}
