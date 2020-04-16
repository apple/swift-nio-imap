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

extension IMAPCore.Flag {

    /// IMAPv4 `flag-keyword`
    public enum Keyword: Equatable {
        case mdnSent
        case forwarded
        case other(String)
    }

}

extension IMAPCore.Flag.Keyword: ExpressibleByStringLiteral {

    public typealias StringLiteralType = String

    public init(stringLiteral value: Self.StringLiteralType) {
        self = .other(value)
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeFlagKeyword(_ keyword: IMAPCore.Flag.Keyword) -> Int {
        switch keyword {
        case .forwarded:
            return self.writeString("$Forwarded")
        case .mdnSent:
            return self.writeString("$MDNSent")
        case .other(let atom):
            return self.writeString(atom)
        }
    }

}
