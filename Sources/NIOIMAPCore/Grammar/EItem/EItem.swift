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

/// IMAPv4 `eitem-vendor-tag`
public struct EItemVendorTag: Equatable {
    public var token: String
    public var atom: String

    public init(token: String, atom: String) {
        self.token = token
        self.atom = atom
    }
}
