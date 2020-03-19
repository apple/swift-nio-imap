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
    public typealias UserID = String
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeUserID(_ id: NIOIMAP.UserID) -> Int {
        self.writeString(id)
    }
    
}
