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

extension MailboxInfo {
    
    /// IMAPv4 `mbx-list-sflag`
    public enum SFlag: String, Equatable {
        case noSelect = #"\Noselect"#
        case marked = #"\Marked"#
        case unmarked = #"\Unmarked"#
        case nonExistent = #"\Nonexistent"#

        public init?(rawValue: String) {
            switch rawValue.lowercased() {
            case #"\noselect"#:
                self = .noSelect
            case #"\marked"#:
                self = .marked
            case #"\unmarked"#:
                self = .unmarked
            case #"\nonexistent"#:
                self = .nonExistent
            default:
                return nil
            }
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxListSFlag(_ flag: MailboxInfo.SFlag) -> Int {
        self.writeString(flag.rawValue)
    }
}
