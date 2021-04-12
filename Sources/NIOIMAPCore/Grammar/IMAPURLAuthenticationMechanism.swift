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

/// The type of authentication mechanism
public enum IMAPURLAuthenticationMechanism: Equatable {
    /// The client should select any appropriate authentication mechanism.
    case any

    /// The client must use the specified authentication mechanism.
    case type(EncodedAuthenticationType)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMAPURLAuthenticationMechanism(_ data: IMAPURLAuthenticationMechanism) -> Int {
        switch data {
        case .any:
            return self.writeString(";AUTH=*")
        case .type(let type):
            return self.writeString(";AUTH=") + self.writeEncodedAuthenticationType(type)
        }
    }
}
