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

import struct NIO.ByteBuffer

/// A `NamespaceResponse` contains descriptions of the user's personal
/// namespace(s), other users' namespace(s), and shared namespaces.
public struct NamespaceResponse: Hashable, Sendable {
    /// Descriptions of the current user's namespaces.
    public var userNamespace: [NamespaceDescription]

    /// Descriptions of other user's namespaces.
    public var otherUserNamespace: [NamespaceDescription]

    /// Descriptions of shared namespaces.
    public var sharedNamespace: [NamespaceDescription]

    /// Creates a new `NamespaceResponse`
    /// - parameter userNamespace: Descriptions of the current user's namespaces.
    /// - parameter otherUserNamespace: Descriptions of other user's namespaces.
    /// - parameter sharedNamespace: Descriptions of shared namespaces.
    public init(
        userNamespace: [NamespaceDescription],
        otherUserNamespace: [NamespaceDescription],
        sharedNamespace: [NamespaceDescription]
    ) {
        self.userNamespace = userNamespace
        self.otherUserNamespace = otherUserNamespace
        self.sharedNamespace = sharedNamespace
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceResponse(_ response: NamespaceResponse) -> Int {
        self.writeString("NAMESPACE ") + self.writeNamespace(response.userNamespace) + self.writeSpace()
            + self.writeNamespace(response.otherUserNamespace) + self.writeSpace()
            + self.writeNamespace(response.sharedNamespace)
    }
}
