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

/// The COPYUID response code returned after a successful COPY or MOVE command.
///
/// When a COPY or MOVE command completes successfully, the server may return this response code
/// containing the UID validity of the destination mailbox and two parallel sets of UIDs. The first
/// set contains the UIDs of the source messages (in the source mailbox), and the second set contains
/// the UIDs assigned to the copied messages in the destination mailbox. This allows clients to
/// correlate copied messages without issuing separate SEARCH commands. See [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315)
/// (UIDPLUS Extension) for details.
///
/// ### Example
///
/// ```
/// C: A001 COPY 1:3 Archive
/// S: A001 OK [COPYUID 42 1:3 101:103] COPY completed
/// ```
///
/// The response code `[COPYUID 42 1:3 101:103]` indicates that messages with UIDs 1, 2, 3 from the
/// source mailbox were copied to the destination mailbox (with UID validity 42) and assigned UIDs
/// 101, 102, 103 respectively.
///
/// - Note: This type uses `[UIDRange]` instead of ``MessageIdentifierSetNonEmpty`` to preserve
///   array ordering, allowing source UIDs to be matched with their corresponding destination UIDs.
///
/// - SeeAlso: [RFC 4315](https://datatracker.ietf.org/doc/html/rfc4315) - UIDPLUS Extension, [RFC 6851](https://datatracker.ietf.org/doc/html/rfc6851) - MOVE Extension
public struct ResponseCodeCopy: Hashable, Sendable {
    /// The UID validity value of the destination mailbox.
    ///
    /// This value allows clients to validate that the destination UIDs are still correct if
    /// referenced later. If the UID validity of the destination mailbox changes, the cached
    /// destination UIDs become invalid.
    ///
    /// - SeeAlso: ``UIDValidity``
    public var destinationUIDValidity: UIDValidity

    /// The message UIDs in the source mailbox (as an ordered array of ranges).
    ///
    /// Each range in this array corresponds to a message or group of consecutive messages in the
    /// source mailbox. The order and count must match the ``destinationUIDs`` array.
    ///
    /// - SeeAlso: ``UIDRange``
    public var sourceUIDs: [UIDRange]

    /// The copied message UIDs assigned in the destination mailbox (as an ordered array of ranges).
    ///
    /// Each range in this array corresponds to the destination UID(s) assigned to the source messages
    /// at the matching index. The order and count must match the ``sourceUIDs`` array.
    ///
    /// - SeeAlso: ``UIDRange``
    public var destinationUIDs: [UIDRange]

    /// Creates a new `ResponseCodeCopy`.
    /// - parameter destinationUIDValidity: The UID validity of the destination mailbox.
    /// - parameter sourceUIDs: The UIDs of the source messages.
    /// - parameter destinationUIDs: The UIDs assigned to the copied messages.
    public init(destinationUIDValidity: UIDValidity, sourceUIDs: [UIDRange], destinationUIDs: [UIDRange]) {
        self.destinationUIDValidity = destinationUIDValidity
        self.sourceUIDs = sourceUIDs
        self.destinationUIDs = destinationUIDs
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseCodeCopy(_ data: ResponseCodeCopy) -> Int {
        self.writeString("COPYUID \(data.destinationUIDValidity.rawValue) ") + self.writeUIDRangeArray(data.sourceUIDs)
            + self.writeSpace() + self.writeUIDRangeArray(data.destinationUIDs)
    }

    @discardableResult private mutating func writeUIDRangeArray(_ array: [UIDRange]) -> Int {
        self.writeArray(array, separator: ",", parenthesis: false) { (element, self) in
            self.writeMessageIdentifierRange(element)
        }
    }
}
