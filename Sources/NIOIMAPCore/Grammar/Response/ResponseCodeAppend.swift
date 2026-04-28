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

/// The `APPENDUID` response code returned after a successful `APPEND` command.
///
/// When an `APPEND` command completes successfully, the server may return this response code
/// containing the UID validity of the destination mailbox and the UIDs assigned to the appended
/// messages. This allows clients to immediately know the UID values without issuing a separate
/// `SEARCH` command. See [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) (UIDPLUS Extension)
/// for details.
///
/// ### Example
///
/// ```
/// C: A001 APPEND INBOX {12}
/// C: Hello World.
/// S: A001 OK [APPENDUID 42 123:125] APPEND completed
/// ```
///
/// The response code `[APPENDUID 42 123:125]` corresponds to this type, indicating that three
/// messages were appended to the mailbox with UID validity 42, assigned UIDs 123, 124, and 125.
///
/// - SeeAlso: [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) - UIDPLUS Extension
public struct ResponseCodeAppend: Hashable, Sendable {
    /// The UID validity value of the destination mailbox.
    ///
    /// Allows clients to validate that the UIDs returned in this response are still
    /// correct if they are later referenced. If the UID validity changes, all cached UIDs are invalid.
    ///
    /// - SeeAlso: ``UIDValidity``
    public var uidValidity: UIDValidity

    /// The UIDs of the messages after they have been appended.
    ///
    /// Contains the UID or UIDs assigned by the server to the messages that were just
    /// appended. The sequence and count of UIDs corresponds to the number of messages appended by
    /// the APPEND command.
    ///
    /// - SeeAlso: ``MessageIdentifierSetNonEmpty``, ``UID``
    public var uids: MessageIdentifierSetNonEmpty<UID>

    /// Creates a new `ResponseCodeAppend`.
    /// - parameter uidValidity: The UID validity of the destination mailbox.
    /// - parameter uids: The UIDs of the appended messages.
    public init(uidValidity: UIDValidity, uids: MessageIdentifierSetNonEmpty<UID>) {
        self.uidValidity = uidValidity
        self.uids = uids
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseCodeAppend(_ data: ResponseCodeAppend) -> Int {
        self.writeString("APPENDUID \(data.uidValidity.rawValue) ") + self.writeUIDSet(data.uids)
    }
}
