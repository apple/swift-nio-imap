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

extension IMAPCore {

    /// IMAP4 `child-mbx-flag`
    public enum ChildMailboxFlag: String, Equatable {
        case HasChildren = #"\HasChildren"#
        case HasNoChildren = #"\HasNoChildren"#
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeChildMailboxFlag(_ flag: IMAPCore.ChildMailboxFlag) -> Int {
        self.writeString(flag.rawValue)
    }

}
