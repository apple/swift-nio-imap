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

/// Used optionally in an IMAP URL to specify the latest date and time that the URL is valid.
public struct Expire: Equatable {
    /// The latest date and time that an IMAP URL is valid.
    public var dateTime: FullDateTime

    /// Creates a new `Expire`.
    /// - parameter dateTime: The latest date and time that an IMAP URL is valid.
    public init(dateTime: FullDateTime) {
        self.dateTime = dateTime
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeExpire(_ data: Expire) -> Int {
        self._writeString(";EXPIRE=") +
            self.writeFullDateTime(data.dateTime)
    }
}
