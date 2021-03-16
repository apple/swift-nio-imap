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

/// Represents an IMAP permanent flag - a flag that persists across sessions.
public enum PermanentFlag: Hashable {
    /// A specific flag that can be or is permanent.
    case flag(Flag)

    /// A wildcard to say any flag may be made permanent
    case wildcard
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeFlagPerm(_ flagPerm: PermanentFlag) -> Int {
        switch flagPerm {
        case .flag(let flag):
            return self.writeFlag(flag)
        case .wildcard:
            return self.writeString(#"\*"#)
        }
    }

    @discardableResult mutating func writePermanentFlags(_ flags: [PermanentFlag]) -> Int {
        self.writeArray(flags) { (element, self) in
            self.writeFlagPerm(element)
        }
    }
}
