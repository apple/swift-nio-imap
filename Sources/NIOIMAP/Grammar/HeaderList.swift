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
    
    /// IMAPv4 `header-list`
    public typealias HeaderList = [String]
    
}

extension ByteBuffer {
    
    @discardableResult mutating func writeHeaderList(_ headers: [String]) -> Int {
        self.writeArray(headers) { (element, self) in
            self.writeAString(element)
        }
    }
    
}
