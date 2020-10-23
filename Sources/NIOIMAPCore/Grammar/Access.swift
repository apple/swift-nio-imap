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

import struct NIO.ByteBuffer

/// Defined in RFC 5092.
/// Defines various access levels that may be used to fetch IMAP URLs.
/// Recomended reading: RFC 5092 § 6.1.
public enum Access: Equatable {
    /// Restricts use of an IMAP URL to sessions identifying as a message submission entity on behalf of the given `EncodedUser`
    case submit(EncodedUser)

    /// Restricts use of an IMAP URL to IMAP sessions that are authenticated as the given `EncodedUser`.
    case user(EncodedUser)

    /// Restricts use of an IMAP URL to authenticated IMAP sessions, logged in as a non-anonymous user.
    case authUser

    /// Allows non-restricted fetching of an IMAP URL, including non-authenticated sessions.
    case anonymous
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAccess(_ data: Access) -> Int {
        switch data {
        case .submit(let user):
            return self.writeString("submit+") + self.writeEncodedUser(user)
        case .user(let user):
            return self.writeString("user+") + self.writeEncodedUser(user)
        case .authUser:
            return self.writeString("authuser")
        case .anonymous:
            return self.writeString("anonymous")
        }
    }
}
