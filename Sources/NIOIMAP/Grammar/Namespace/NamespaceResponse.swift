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

    /// IMAPv4 `Namespace-Response`
    public struct NamespaceResponse: Equatable {
        public let userNamespace: Namespace
        public let otherUserNamespace: Namespace
        public let sharedNamespace: Namespace

        public static func userNamespace(_ userNamespace: Namespace, otherUserNamespace: Namespace, sharedNamespace: Namespace) -> Self {
            return Self(userNamespace: userNamespace, otherUserNamespace: otherUserNamespace, sharedNamespace: sharedNamespace)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeNamespaceResponse(_ response: NIOIMAP.NamespaceResponse) -> Int {
        self.writeString("NAMESPACE ") +
        self.writeNamespace(response.userNamespace) +
        self.writeSpace() +
        self.writeNamespace(response.otherUserNamespace) +
        self.writeSpace() +
        self.writeNamespace(response.sharedNamespace)
    }

}
