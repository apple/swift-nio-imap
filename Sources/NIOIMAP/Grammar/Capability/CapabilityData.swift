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
    
    /// IMAPv4 `capability-data`
    public typealias CapabilityData = [Capability]

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeCapabilityData(_ data: NIOIMAP.CapabilityData) -> Int {
        self.writeString("CAPABILITY IMAP4 IMAP4rev1") +
        self.writeArray(data, separator: "", parenthesis: false) { (capability, self) -> Int in
            self.writeSpace() +
            self.writeCapability(capability)
        }
    }

}
