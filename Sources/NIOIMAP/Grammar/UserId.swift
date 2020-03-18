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

import NIO

extension NIOIMAP {
    
    /// IMAPv4 `userid`
    public typealias UserId = String
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeUserId(_ id: NIOIMAP.UserId) -> Int {
        self.writeString(id)
    }
    
}
