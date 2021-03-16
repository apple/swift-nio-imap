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

/// Untagged status responses
///
/// The untagged versions in RFC 3501 section 7.1
public enum UntaggedStatus: Equatable {
    /// Indicates a success.
    case ok(ResponseText)

    /// Indicates an operational error message from the
    /// server.  When tagged, it indicates unsuccessful completion of the
    /// associated command.  The untagged form indicates a warning; the
    /// command can still complete successfully.  The human-readable text
    /// describes the condition.
    case no(ResponseText)

    /// The BAD response indicates an error message from the server.  When
    /// tagged, it reports a protocol-level error in the client's command;
    /// the tag indicates the command that caused the error.  The untagged
    /// form indicates a protocol-level error for which the associated
    /// command can not be determined; it can also indicate an internal
    /// server failure.  The human-readable text describes the condition.
    case bad(ResponseText)

    /// The PREAUTH response is always untagged, and is one of three
    /// possible greetings at connection startup.  It indicates that the
    /// connection has already been authenticated by external means; thus
    /// no LOGIN command is needed.
    case preauth(ResponseText)

    /// The BYE response is always untagged, and indicates that the server
    /// is about to close the connection.  The human-readable text MAY be
    /// displayed to the user in a status report by the client.
    case bye(ResponseText)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeUntaggedStatus(_ cond: UntaggedStatus) -> Int {
        switch cond {
        case .ok(let text):
            return
                self._writeString("OK ") +
                self.writeResponseText(text)
        case .no(let text):
            return
                self._writeString("NO ") +
                self.writeResponseText(text)
        case .bad(let text):
            return
                self._writeString("BAD ") +
                self.writeResponseText(text)
        case .preauth(let text):
            return
                self._writeString("PREAUTH ") +
                self.writeResponseText(text)
        case .bye(let text):
            return
                self._writeString("BYE ") +
                self.writeResponseText(text)
        }
    }
}
