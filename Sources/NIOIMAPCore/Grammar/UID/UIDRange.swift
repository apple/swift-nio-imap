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

/// IMAPv4 `uid-range`
public struct UIDRange: Equatable {
    public var left: Int
    public var right: Int

    public init(left: Int, right: Int) {
        self.left = left
        self.right = right
    }
}
