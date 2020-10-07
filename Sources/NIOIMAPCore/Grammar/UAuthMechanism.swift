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
public struct UAuthMechanism: Equatable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let `internal` = Self(rawValue: "INTERNAL")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUAuthMechanism(_ data: UAuthMechanism) -> Int {
        self.writeString(data.rawValue)
    }
}
