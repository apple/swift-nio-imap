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

// RFC 5464
public struct ScopeOption: Equatable {
    enum _Backing: String {
        case zero = "0"
        case one = "1"
        case infinity
    }

    var _backing: _Backing

    static var zero = Self(_backing: .zero)

    static var one = Self(_backing: .one)

    static var infinity = Self(_backing: .infinity)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeScopeOption(_ opt: ScopeOption) -> Int {
        self.writeString("DEPTH \(opt._backing.rawValue)")
    }
}
