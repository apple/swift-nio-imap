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

/// A modifier that restricts which messages are returned by the `FETCH` command (RFC 3501 and extensions).
///
/// The `FETCH` command supports optional modifiers that allow clients to retrieve only messages meeting specific criteria,
/// such as those modified since a certain point or within a specific range. These modifiers work alongside ``FetchAttribute``
/// to control both what data is returned and which messages are included in the response.
///
/// ### Examples
///
/// ```
/// C: A001 FETCH 1:* (FLAGS INTERNALDATE) (CHANGEDSINCE 12345)
/// S: * 2 FETCH (FLAGS (\Seen) INTERNALDATE "17-Jul-1996 09:01:33 -0700")
/// S: * 5 FETCH (FLAGS (\Draft) INTERNALDATE "18-Jul-1996 14:22:10 -0700")
/// S: A001 OK FETCH completed
/// ```
///
/// The `(CHANGEDSINCE 12345)` portion represents ``changedSince(_:)`` modifier. Only messages with mod-sequence
/// values greater than or equal to 12345 are included in the response.
///
/// - SeeAlso: [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6)
/// - SeeAlso: ``FetchAttribute``
public enum FetchModifier: Hashable, Sendable {
    /// Return only messages whose modification sequence (mod-seq) has changed since a reference point (RFC 7162 `CONDSTORE` extension).
    ///
    /// When specified, only messages with a mod-sequence value greater than or equal to the specified value
    /// are returned. This allows clients to efficiently synchronize mailbox state changes without transferring
    /// unchanged messages.
    ///
    /// **Requires server capability:** ``Capability/condStore``
    ///
    /// - SeeAlso: [RFC 7162 Section 3.1.4](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.4)
    case changedSince(ChangedSinceModifier)

    /// Return only a specified range of results for paginated `FETCH` (RFC 9394 `PARTIAL` extension).
    ///
    /// Allows clients to fetch results in pages without retrieving all messages. The range specifies
    /// which results from the logical result set to return, enabling efficient handling of large mailboxes
    /// on clients with limited bandwidth or storage.
    ///
    /// **Requires server capability:** ``Capability/partial``
    ///
    /// - SeeAlso: [RFC 9394](https://datatracker.ietf.org/doc/html/rfc9394)
    case partial(PartialRange)

    /// A server extension modifier not defined in this library.
    ///
    /// This case captures future `FETCH` modifiers defined by extensions, allowing forward compatibility
    /// with new IMAP capabilities without requiring library updates.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchModifier(_ val: FetchModifier) -> Int {
        switch val {
        case .changedSince(let changedSince):
            return self.writeChangedSinceModifier(changedSince)
        case .partial(let range):
            return self.writeString("PARTIAL ") + self.writePartialRange(range)
        case .other(let param):
            return self.writeParameter(param)
        }
    }

    @discardableResult mutating func writeFetchModifiers(_ a: [FetchModifier]) -> Int {
        if a.isEmpty {
            return 0
        }
        return self.writeSpace()
            + self.writeArray(a) { (modifier, self) in
                self.writeFetchModifier(modifier)
            }
    }
}
