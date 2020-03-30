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

// MARK: - NString
extension NIOIMAP {

    /// IMAPv4 `nstring`
    public typealias NString = ByteBuffer?
    
}

// MARK: - IMAP
extension ByteBuffer {
    
    @discardableResult mutating func writeNString(_ string: NIOIMAP.NString) -> Int {
        if let string = string {
            return self.writeIMAPString(string)
        } else {
            return self.writeNil()
        }
    }
    
}
