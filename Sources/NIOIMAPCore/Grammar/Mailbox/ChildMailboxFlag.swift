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

/// IMAP4 `child-mbx-flag`
public struct ChildMailboxFlag: Equatable {
    
    enum _Backing: String, Equatable {
        case hasChildren = #"\hasChildren"#
        case hasNoChildren = #"\hasNoChildren"#
    }
    
    var _backing: _Backing
    
    public static var hasChildren: Self { Self(_backing: .hasChildren) }
    public static var hasNoChildren: Self { Self(_backing: .hasNoChildren) }
    
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeChildMailboxFlag(_ flag: ChildMailboxFlag) -> Int {
        self.writeString(flag._backing.rawValue)
    }
}
