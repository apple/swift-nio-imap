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

    /// IMAPv4 `Namespace`
    public typealias Namespace = [NamespaceDescription]?

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeNamespace(_ namespace: NIOIMAP.Namespace) -> Int {
        if let namespace = namespace {
            return self.writeArray(namespace, separator: "") { (description, self) in
                self.writeNamespaceDescription(description)
            }
        } else {
            return self.writeNil()
        }
    }
    
}
