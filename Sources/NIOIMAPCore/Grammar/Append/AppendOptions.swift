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
import struct OrderedCollections.OrderedDictionary

/// Optional metadata to attach to a message in an `APPEND` command.
///
/// An `AppendOptions` struct allows clients to specify flags, internal date, and
/// extension fields when appending a message to a mailbox (RFC 3501). These options
/// are optional; messages can be appended without any flags or date. This is also used
/// when catenating messages using the `CATENATE` extension (RFC 4469).
///
/// ### Example
///
/// ```
/// C: A001 APPEND INBOX (\Seen \Flagged) "17-Jul-1996 09:01:33 -0700" {1234}
/// S: + Ready for literal data
/// C: <1234 bytes of message data>
/// S: * 10 EXISTS
/// S: A001 OK APPEND completed
/// ```
///
/// The `(\Seen \Flagged) "17-Jul-1996 09:01:33 -0700"` portion is represented as
/// an `AppendOptions` with `flagList: [.seen, .flagged]` and the internal date.
///
/// - SeeAlso: [RFC 3501 Section 6.3.11](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.11) (APPEND Command)
/// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (CATENATE Extension)
/// - SeeAlso: ``Flag``, ``AppendMessage``, ``AppendCommand/beginCatenate(options:)``
public struct AppendOptions: Hashable, Sendable {
    /// Flags to be added to the message.
    ///
    /// A list of standard flags (like `\Seen`, `\Flagged`, `\Draft`) or custom keyword
    /// flags to be set on the message when it is appended. If empty, no flags are set
    /// on the new message.
    ///
    /// - SeeAlso: ``Flag``
    public var flagList: [Flag]

    /// The internal date associated with the message.
    ///
    /// Typically represents the date of message delivery. If `nil`, the server assigns
    /// the current date as the internal date. The internal date affects mailbox search
    /// results for date-based queries.
    ///
    /// - SeeAlso: ``ServerMessageDate``
    public var internalDate: ServerMessageDate?

    /// Extension fields for future IMAP extensions.
    ///
    /// Implemented as a catch-all to support new extension parameters that may be added
    /// to `APPEND` in the future without requiring code changes. Extensions that don't
    /// match standard options are stored here as key-value pairs.
    public var extensions: OrderedDictionary<String, ParameterValue>

    /// Empty options with no flags, date, or extensions.
    ///
    /// Provided as convenience to create an `APPEND` without any metadata.
    public static let none = Self()

    /// Creates a new set of append options.
    ///
    /// - parameter flagList: Flags to add to the message. Defaults to no flags.
    /// - parameter internalDate: Optional date to associate with the message. Defaults to `nil`.
    /// - parameter extensions: Extension fields for future extensions. Defaults to empty.
    public init(
        flagList: [Flag] = [],
        internalDate: ServerMessageDate? = nil,
        extensions: OrderedDictionary<String, ParameterValue> = [:]
    ) {
        self.flagList = flagList
        self.internalDate = internalDate
        self.extensions = extensions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAppendOptions(_ options: AppendOptions) -> Int {
        self.write(if: options.flagList.count >= 1) {
            self.writeSpace() + self.writeFlags(options.flagList)
        }
            + self.writeIfExists(options.internalDate) { (internalDate) -> Int in
                self.writeSpace() + self.writeInternalDate(internalDate)
            }
            + self.writeOrderedDictionary(options.extensions, prefix: " ", parenthesis: false) { (ext, self) -> Int in
                self.writeTaggedExtension(ext)
            }
    }
}
