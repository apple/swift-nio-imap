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
public struct UseAttribute: Equatable, RawRepresentable {
    public typealias RawValue = String

    /// A mailbox that presents all messages in the user's store.
    public static var all = Self(rawValue: "\\All")

    /// Used to archive messages - note that the meaning of "archived" will vary from server to server.
    public static var archive = Self(rawValue: "\\Archive")

    /// Used to store draft messages that have not been sent.
    public static var drafts = Self(rawValue: "\\Drafts")

    /// Stores messages that have been marked as "important" for some reason.
    public static var flagged = Self(rawValue: "\\Flagged")

    /// Stores messages deemed to be spam of junk mail, e.g. from a mailing list.
    public static var junk = Self(rawValue: "\\Junk")

    /// Holds copies of messages that have been sent.
    public static var sent = Self(rawValue: "\\Sent")

    /// Holds messages that have been deleted or marked for deletion.
    public static var trash = Self(rawValue: "\\Trash")

    /// The raw value of the attribute, e.g. `\\Trash`.
    public var rawValue: String

    /// Creates a new `UseAttribute` from the raw `String`. Note that
    /// usually it should be sufficient to just use the predefined attributes, e.g. `.drafts`.
    /// `rawValue` will be lowercased.
    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUseAttribute(_ att: UseAttribute) -> Int {
        self.writeString(att.rawValue)
    }
}
