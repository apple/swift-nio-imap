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

/// The UID was invalid because the underlying number was not `> 0`.
public struct InvalidUID: Error {}

/// Wraps an IMAP4 message Unique Identifier (UID), and it
/// SHOULD be used as the <set> argument to the IMAP4 "UID FETCH"
/// command.
public struct IUID: Equatable {
    /// The wrapped `UID`
    public var uid: Int

    /// Creates a new `IUID` from a raw value.
    /// - parameter uid: The raw value to use.
    /// - throws: An `InvalidUID` if `uid == 0`.
    public init(uid: Int) throws {
        guard uid > 0 else {
            throw InvalidUID()
        }
        self.uid = uid
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUID(_ data: IUID) -> Int {
        self.writeString("/;UID=\(data.uid)")
    }

    @discardableResult mutating func writeIUIDOnly(_ data: IUID) -> Int {
        self.writeString(";UID=\(data.uid)")
    }
}
