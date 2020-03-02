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

    /// IMAP4 `eitem-standard-tag`
    public typealias EItemStandardTag = Atom

    /// IMAPv4 `eitem-vendor-tag`
    public struct EItemVendorTag: Equatable {
        var token: VendorToken
        var atom: Atom
    }

}
