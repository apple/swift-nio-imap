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

/// The name of the algorithm used to generate and verify a URLAUTH.
public struct UAuthMechanism: Equatable {
    /// Uses a token generation algorithm of the server's choosing
    public static let `internal` = Self("INTERNAL")

    /// The raw name of the generation algorithm.
    public var stringValue: String

    /// Creates a new UAuthMechanism from the name of an algorithm.
    /// - parameter rawValue: The name of an algorithm.
    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUAuthMechanism(_ data: UAuthMechanism) -> Int {
        self.writeString(data.stringValue)
    }
}
