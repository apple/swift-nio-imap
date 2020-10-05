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

/// RFC 5092
public struct Expire: Equatable {
    
    public var dateTime: FullDateTime
    
    public init(dateTime: FullDateTime) {
        self.dateTime = dateTime
    }
    
}

// MARK: - Encoding

extension EncodeBuffer {
    
    @discardableResult mutating func writeExpire(_ data: Expire) -> Int {
        self.writeString(";EXPIRE=") +
            self.writeFullDateTime(data.dateTime)
    }
    
}
