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

/// An error indicating that a UID value was invalid (zero or less).
///
/// IMAP UIDs must be greater than zero. This error is raised if an invalid UID value
/// is provided to constructors or validators.
public struct InvalidUID: Error {}

/// A wrapped ``UID`` for use in IMAP URL constructs and CATENATE operations.
///
/// The `IUID` type wraps a ``UID`` and provides encoding compatible with IMAP URL and
/// CATENATE extension syntax. It is used in operations that reference message content by
/// URL-style paths, particularly in RFC 4469 CATENATE and RFC 5092 IMAP URL contexts.
///
/// In IMAP URL/CATENATE format, a UID is encoded as:
/// - `;UID=<uid-value>` (in relative paths or CATENATE operations)
/// - `/;UID=<uid-value>` (in absolute message paths)
///
/// This type is primarily used internally for IMAP URL constructs and CATENATE append
/// operations that reference existing messages on the server.
///
/// See [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (CATENATE Extension)
/// for details on how IUIDs are used to reference message content.
///
/// ## Related Types
///
/// - ``UID`` is the wrapped type containing the actual message identifier.
public struct IUID: Hashable, Sendable {
    /// The wrapped ``UID`` value.
    ///
    /// - Returns: The underlying UID for this IUID.
    public var uid: UID

    /// Creates a new `IUID` from a ``UID``.
    ///
    /// - parameter uid: The `UID` to wrap.
    public init(uid: UID) {
        self.uid = uid
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUID(_ data: IUID) -> Int {
        self.writeString("/;UID=\(data.uid)")
    }

    @discardableResult mutating func writeIUIDOnly(_ data: IUID) -> Int {
        self.writeString(";UID=\(data.uid)")
    }
}
