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

/// IMAPv4 `response-code-copy`
public struct ResponseCodeCopy: Equatable {
    public var num: Int
    public var set1: [UIDSetType]
    public var set2: [UIDSetType]

    public init(num: Int, set1: [NIOIMAP.UIDSetType], set2: [NIOIMAP.UIDSetType]) {
        self.num = num
        self.set1 = set1
        self.set2 = set2
    }
}
