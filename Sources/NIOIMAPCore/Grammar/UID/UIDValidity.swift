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

/// RFC 5092 IMAP URL
public struct UIDValidity: Equatable {
    public var uid: Int

    public init(uid: Int) throws {
        guard uid > 0 else {
            throw InvalidUID()
        }
        self.uid = uid
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidaty(_ data: UIDValidity) -> Int {
        self.writeString(";UIDVALIDITY=\(data.uid)")
    }
}
