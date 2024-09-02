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

/// Used an option to `.getMetadata` to specify the depth.
public struct ScopeOption: Hashable, Sendable {
    /// No entries below the specified entry are returned
    public static let zero = Self(_backing: .zero)

    /// Only entries immediately below the specified entry are returned
    public static let one = Self(_backing: .one)

    /// All entries below the specified entry are returned
    public static let infinity = Self(_backing: .infinity)

    enum _Backing: String {
        case zero = "0"
        case one = "1"
        case infinity
    }

    let _backing: _Backing
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeScopeOption(_ opt: ScopeOption) -> Int {
        self.writeString("DEPTH \(opt._backing.rawValue)")
    }
}
