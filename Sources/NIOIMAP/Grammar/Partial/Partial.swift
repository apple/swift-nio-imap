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

    /// IMAPv4 `partial`
    public struct Partial: Equatable {
        public var left: Number
        public var right: NZNumber
        
        public init(left: Number, right: NZNumber) {
            self.left = left
            self.right = right
        }
    }
    
}

extension ByteBuffer {
    
    @discardableResult mutating func writePartial(_ num: NIOIMAP.Partial) -> Int {
        self.writeString("<\(num.left).\(num.right)>")
    }
    
}
