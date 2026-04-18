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

/// A flag that can be or is permanent on the mailbox.
///
/// In IMAP, servers indicate which flags can be made persistent (saved across sessions) via the `PERMANENTFLAGS`
/// response code. A permanent flag is either a specific ``Flag`` that will persist or a wildcard indicating
/// that any flag can be made permanent.
///
/// Permanent flags are communicated to clients in [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
/// `SELECT` responses, allowing clients to know which flags are worth setting on messages.
///
/// ### Example
///
/// ```
/// C: A001 SELECT INBOX
/// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
/// S: * OK [PERMANENTFLAGS (\Answered \Flagged \Deleted \Seen \Draft \*)] Flags permitted.
/// S: A001 OK SELECT completed
/// ```
///
/// The line `[PERMANENTFLAGS (\Answered \Flagged \Deleted \Seen \Draft \*)]` indicates that all standard flags
/// plus any custom flag (represented by the wildcard) can be made permanent. Each flag corresponds to a
/// ``PermanentFlag/flag(_:)`` case, and the `\*` corresponds to ``PermanentFlag/wildcard``.
///
/// - SeeAlso: [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
/// - SeeAlso: ``Flag``
public enum PermanentFlag: Hashable, Sendable {
    /// A specific flag that can be or is permanent on this mailbox.
    ///
    /// When present, indicates that this particular flag can be set on messages and will persist across sessions.
    case flag(Flag)

    /// A wildcard indicating that any flag may be made permanent.
    ///
    /// When present, indicates that clients can set arbitrary custom flags on messages and they will persist.
    case wildcard
}

extension PermanentFlag: CustomDebugStringConvertible {
    /// A debug representation showing the permanent flag in IMAP format.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            _ = $0.writeFlagPerm(self)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
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
