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

    /// IMAPv4 `search-program`
    public struct SearchProgram: Equatable {
        public var charset: String?
        public var keys: [SearchKey]

        public static func charset(_ charset: String?, keys: [SearchKey]) -> Self {
            return Self(charset: charset, keys: keys)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeSearchProgram(_ program: NIOIMAP.SearchProgram) -> Int {
        self.writeIfExists(program.charset) { (charset) -> Int in
            self.writeString("CHARSET \(charset) ")
        } +
        self.writeArray(program.keys, parenthesis: false) { (key, self) in
            self.writeSearchKey(key)
        }
    }

}
