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


extension NIOIMAP {

    /// IMAPv4 `response-code-copy`
    public struct ResponseCodeCopy: Equatable {
        public var num: Int
        public var set1: [UIDSetType]
        public var set2: [UIDSetType]
        
        public static func num(_ num: Int, set1: [UIDSetType], set2: [UIDSetType]) -> Self {
            return Self(num: num, set1: set1, set2: set2)
        }
    }

}
