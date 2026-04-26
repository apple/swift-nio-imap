//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A message identifier that can be either a specific value or a reference to the last `SEARCH` result.
///
/// The `LastCommandMessageID` enum allows a client to reference a specific message identifier or
/// to use the `$` marker, which tells the server to use the result of the most recent `SEARCH`
/// command. This is defined in RFC 5182.
///
/// **Requires server capability:** ``Capability/searchRes``
///
/// The `$` marker can be used anywhere a single message identifier is expected. It allows clients
/// to pipeline a `SEARCH` command with subsequent operations (like `FETCH`, `STORE`, `COPY`) without
/// waiting for results and reformatting them.
///
/// ## Difference from LastCommandSet
///
/// - ``LastCommandMessageID`` references a single message identifier or the `$` result.
/// - ``LastCommandSet`` references a message set (multiple identifiers) or the `$` result.
/// - Both require the same `SEARCHRES` capability and serve the same purpose: avoiding result transmission overhead.
///
/// ## Examples
///
/// ```
/// // Fetch the result of the last search (single message)
/// C: A001 UID FETCH $ BODY[TEXT]
/// S: * 7 FETCH (BODY[TEXT] {8}
/// S: some text)
/// S: A001 OK FETCH completed
/// ```
///
/// The `$` marker is equivalent to using the UID/sequence number returned by the
/// most recent `SEARCH` or `UID SEARCH` command, but without the overhead of transmitting
/// and reparsing the message identifier on every command.
///
/// See [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182) for the full specification
/// of the search result reference extension.
///
/// ## Related types
///
/// - ``LastCommandSet`` allows referencing the last search result as a message set instead of a single identifier.
/// - ``MessageIdentifier`` represents a specific message identifier (``UID`` or ``SequenceNumber``).
public enum LastCommandMessageID<N: MessageIdentifier>: Hashable {
    /// A specific message identifier (a ``UID`` or ``SequenceNumber``).
    case id(N)

    /// References the result of the most recent `SEARCH` command.
    ///
    /// The `$` marker tells the server to use the set of message identifiers saved from
    /// the last `SEARCH`, `UID SEARCH`, `SORT`, or `THREAD` command (when those commands
    /// include the `SAVE` result option).
    ///
    /// See [RFC 5182 Section 1](https://datatracker.ietf.org/doc/html/rfc5182#section-1) for details.
    case lastCommand
}

extension LastCommandMessageID: Sendable where N: Sendable {}

extension EncodeBuffer {
    @discardableResult mutating func writeLastCommandMessageID<T>(_ set: LastCommandMessageID<T>) -> Int {
        switch set {
        case .lastCommand:
            return self.writeString("$")
        case .id(let num):
            return writeMessageIdentifier(num)
        }
    }
}
