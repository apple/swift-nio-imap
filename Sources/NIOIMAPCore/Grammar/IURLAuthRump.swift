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

/// RFC 5092
public struct IURLAuthRump: Equatable {
    public var expire: Expire?
    public var access: Access

    public init(expire: Expire? = nil, access: Access) {
        self.expire = expire
        self.access = access
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIURLAuthRump(_ data: IURLAuthRump) -> Int {
        self.writeIfExists(data.expire) { expire in
            self.writeExpire(expire)
        } +
            self.writeString(";URLAUTH=") +
            self.writeAccess(data.access)
    }
}
