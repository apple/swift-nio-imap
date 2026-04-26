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

/// A message set that can be either a specific set or a reference to the last `SEARCH` result.
///
/// The `LastCommandSet` enum allows a client to reference a specific set of message identifiers or
/// to use the `$` marker, which tells the server to use the result of the most recent `SEARCH`
/// command. This is defined in RFC 5182.
///
/// **Requires server capability:** ``Capability/searchRes``
///
/// The `$` marker can be used anywhere a message set is expected (for example, in `FETCH`, `STORE`,
/// `COPY`, `EXPUNGE` commands). It allows clients to pipeline a `SEARCH` command with subsequent
/// operations without waiting for results and reformatting them.
///
/// ## Difference from LastCommandMessageID
///
/// - ``LastCommandSet`` references a message set (multiple identifiers) or the `$` result.
/// - ``LastCommandMessageID`` references a single message identifier or the `$` result.
/// - Both require the same `SEARCHRES` capability and serve the same purpose: avoiding result transmission overhead.
///
/// ## Examples
///
/// ```
/// // Delete all messages matching the last search
/// C: A001 UID SEARCH SUBJECT "spam"
/// S: * SEARCH 1 2 5 7 10
/// S: A001 OK SEARCH completed
/// C: A002 UID STORE $ +FLAGS \Deleted
/// S: * 1 FETCH (UID 1 FLAGS (\Deleted))
/// S: * 2 FETCH (UID 2 FLAGS (\Deleted))
/// ...
/// S: A002 OK STORE completed
/// ```
///
/// The `$` marker is equivalent to using the set of UIDs/sequence numbers returned by the
/// most recent `SEARCH` or `UID SEARCH` command, but without the overhead of transmitting
/// and reparsing the message set.
///
/// See [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182) for the full specification
/// of the search result reference extension.
///
/// ## Related types
///
/// - ``LastCommandMessageID`` allows referencing the last search result as a single identifier instead of a set.
/// - ``MessageIdentifierSet`` represents a specific non-empty set of message identifiers.
/// - ``MessageIdentifierSetNonEmpty`` provides a wrapper guaranteeing a non-empty set.
public enum LastCommandSet<N: MessageIdentifier>: Hashable, Sendable {
    /// A specific non-empty set of message identifiers.
    ///
    /// Encoded and sent to the IMAP server. Example values: `1`, `5:10`, or `1,3,5:7,9:*`.
    case set(MessageIdentifierSetNonEmpty<N>)

    /// References the result of the most recent `SEARCH` command.
    ///
    /// The `$` marker tells the server to use the set of message identifiers saved from
    /// the last `SEARCH`, `UID SEARCH`, `SORT`, or `THREAD` command (when those commands
    /// include the `SAVE` result option).
    ///
    /// See [RFC 5182 Section 1](https://datatracker.ietf.org/doc/html/rfc5182#section-1) for details.
    case lastCommand
}

extension LastCommandSet {
    public static func range(_ range: MessageIdentifierRange<N>) -> Self {
        .set(MessageIdentifierSetNonEmpty(range: range))
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeLastCommandSet<T>(_ set: LastCommandSet<T>) -> Int {
        switch set {
        case .lastCommand:
            return self.writeString("$")
        case .set(let set):
            return set.writeIntoBuffer(&self)
        }
    }
}
