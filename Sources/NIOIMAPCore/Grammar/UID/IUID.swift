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
public struct IUID: Equatable {
    public var uid: Int

    public init?(uid: Int) {
        guard uid > 0 else {
            return nil
        }
        self.uid = uid
    }
}

/// RFC 5092 IMAP URL
public struct IUIDOnly: Equatable {
    public var uid: Int

    public init?(uid: Int) {
        guard uid > 0 else {
            return nil
        }
        self.uid = uid
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUID(_ data: IUID) -> Int {
        self.writeString("/;UID=\(data.uid)")
    }

    @discardableResult mutating func writeIUIDOnly(_ data: IUIDOnly) -> Int {
        self.writeString(";UID=\(data.uid)")
    }
}
