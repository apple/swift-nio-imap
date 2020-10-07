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

/// RFC 5092
public enum IAuth: Equatable {
    case any
    case type(EncodedAuthenticationType)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIAuth(_ data: IAuth) -> Int {
        switch data {
        case .any:
            return self.writeString(";AUTH=*")
        case .type(let type):
            return self.writeString(";AUTH=") + self.writeEncodedAuthenticationType(type)
        }
    }
}
