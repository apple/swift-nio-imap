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

extension Partial {
    /// IMAPv4 `partial-range`
    public struct Range: Equatable {
        public var from: Int
        public var to: Int?

        public init(from: Int, to: Int?) {
            self.from = from
            self.to = to
        }
    }
}
