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

/// Pairs an auth URL rump with an optional expiry date and access restrictions.
public struct IRumpAuthenticatedURL: Equatable {
    /// The optional expiry date of the URL.
    public var expire: Expire?

    /// Access restrictions that apply to the URL.
    public var access: Access

    /// Creates a new `IRumpAuthenticatedURL`.
    /// - parameter expire: The optional expiry date of the URL.
    /// - parameter access: Access restrictions that apply to the URL.
    public init(expire: Expire? = nil, access: Access) {
        self.expire = expire
        self.access = access
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIRumpAuthenticatedURL(_ data: IRumpAuthenticatedURL) -> Int {
        self.writeIfExists(data.expire) { expire in
            self.writeExpire(expire)
        } +
            self._writeString(";URLAUTH=") +
            self.writeAccess(data.access)
    }
}
