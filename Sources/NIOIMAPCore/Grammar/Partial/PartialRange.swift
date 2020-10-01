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

/// See RFC 5092
public struct PartialRange: Equatable {
    
    public var offset: Int
    public var length: Int?
    
    public init(offset: Int, length: Int?) {
        self.offset = offset
        self.length = length
    }
    
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writePartialRange(_ data: PartialRange) -> Int {
        self.writeString("\(data.offset)") +
            self.writeIfExists(data.length, callback: { length in
                self.writeString(".\(length)")
            })
    }
    
}
