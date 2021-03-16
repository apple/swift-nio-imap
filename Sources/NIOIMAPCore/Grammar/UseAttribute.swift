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

/// A `UseAttribute` is  a special-use attribute as defined in RFC 6154.
/// They're used to designate a special use to certain mailboxes.
/// The raw `String` value is lower-cased on initialisation to ensure
/// case-insensitive comparison.
public struct UseAttribute: Equatable {
    /// A mailbox that presents all messages in the user's store.
    public static let all = Self("\\All")

    /// Used to archive messages - note that the meaning of "archived" will vary from server to server.
    public static let archive = Self("\\Archive")

    /// Used to store draft messages that have not been sent.
    public static let drafts = Self("\\Drafts")

    /// Stores messages that have been marked as "important" for some reason.
    public static let flagged = Self("\\Flagged")

    /// Stores messages deemed to be spam of junk mail, e.g. from a mailing list.
    public static let junk = Self("\\Junk")

    /// Holds copies of messages that have been sent.
    public static let sent = Self("\\Sent")

    /// Holds messages that have been deleted or marked for deletion.
    public static let trash = Self("\\Trash")

    internal var stringValue: String

    /// Creates a new `UseAttribute` from the raw `String`. Note that
    /// usually it should be sufficient to just use the predefined attributes, e.g. `.drafts`.
    /// `rawValue` will be lowercased.
    public init(_ stringValue: String) {
        self.stringValue = stringValue.lowercased()
    }
}

extension String {
    /// The raw value of the attribute, e.g. `\\trash`. Always lowercase.
    public init(_ other: UseAttribute) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeUseAttribute(_ att: UseAttribute) -> Int {
        self.writeString(att.stringValue)
    }
}
