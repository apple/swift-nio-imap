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

/// A vendor-specific tag for extended list data
public struct EItemVendorTag: Equatable {
    /// A reserved portion of the ACAP namespace. Must be registered with IANA
    public var token: String

    /// Used to identify the type of data.
    public var atom: String

    /// Creates a new `EItemVendorTag`.
    /// - parameter token: A reserved portion of the ACAP namespace. Must be registered with IANA
    /// - parameter atom: Used to identify the type of data.
    public init(token: String, atom: String) {
        self.token = token
        self.atom = atom
    }
}
