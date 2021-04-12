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

/// Returned after a successfully `.uidCopy` command, and provides the new identifier
/// of the appended message, and the uid validity of the destination mailbox.
public struct ResponseCodeAppend: Equatable {
    /// The UID validity of the destination mailbox.
    public var num: Int

    /// The UID of the message after it has been appended.
    public var uid: UID

    /// Creates a new `ResponseCodeAppend`.
    /// - parameter num: The UID validity of the destination mailbox.
    /// - parameter uid: The UID of the message after it has been appended.
    public init(num: Int, uid: UID) {
        self.num = num
        self.uid = uid
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeResponseCodeAppend(_ data: ResponseCodeAppend) -> Int {
        self.writeString("APPENDUID \(data.num) ") +
            self.writeUID(data.uid)
    }
}
