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

    /// IMAPv4 `msg-att-dynamic`
    public typealias MessageAttributesDynamic = [FlagFetch]
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMessageAttributeDynamic(_ atts: NIOIMAP.MessageAttributesDynamic) -> Int {
        self.writeString("FLAGS ") +
        self.writeArray(atts) { (element, self) in
            self.writeFlagFetch(element)
        }
    }

}
