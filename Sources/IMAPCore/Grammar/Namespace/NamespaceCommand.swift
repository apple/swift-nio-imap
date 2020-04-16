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

extension IMAPCore {

    /// IMAPv4 `Namespace-Command`
    public static let NamespaceCommand = "NAMESPACE"
    
}

// MARK: - Encoding
extension ByteBufferProtocol {
    
    @discardableResult mutating func writeNamespaceCommand() -> Int {
        self.writeString(IMAPCore.NamespaceCommand)
    }

}
