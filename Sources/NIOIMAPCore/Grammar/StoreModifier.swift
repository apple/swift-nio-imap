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

/// A modifier that constrains when the `STORE` command modifies message metadata (RFC 3501 and extensions).
///
/// The `STORE` command supports optional modifiers that control whether the server actually performs the requested
/// operation. These modifiers are typically used for conditional storage operations to prevent conflicts when
/// multiple clients are modifying the same mailbox simultaneously.
///
/// Without modifiers, the server unconditionally applies the flag changes. With modifiers, the server only
/// applies changes if specific conditions are met, providing a form of optimistic locking for distributed clients.
///
/// ### Example
///
/// ```
/// C: A001 STORE 1 (UNCHANGEDSINCE 12345) +FLAGS (\Seen)
/// S: * 1 FETCH (FLAGS (\Seen) MODSEQ (12346))
/// S: A001 OK STORE completed
/// ```
///
/// The `(UNCHANGEDSINCE 12345)` portion represents the ``unchangedSince(_:)`` modifier. The server only
/// sets the `\Seen` flag if the message's current mod-sequence is 12345 or lower. If a different client has
/// modified the message (increasing its mod-sequence), the `STORE` operation is rejected.
///
/// - SeeAlso: [RFC 7162 Section 3.1.3](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.3)
public enum StoreModifier: Hashable, Sendable {
    /// Only perform the store operation if the message's modification sequence is unchanged (RFC 7162 `CONDSTORE` extension).
    ///
    /// Implements optimistic concurrency control. The server compares the message's current mod-sequence
    /// with the specified value. If the message's mod-sequence is equal to or less than the specified value, the `STORE`
    /// operation succeeds. Otherwise, the operation is rejected, indicating that another client has modified the message.
    ///
    /// Prevents "lost updates" where one client's changes could overwrite another client's changes in a
    /// multimailbox environment.
    ///
    /// **Requires server capability:** ``Capability/condStore``
    ///
    /// - SeeAlso: [RFC 7162 Section 3.1.3](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.3)
    case unchangedSince(UnchangedSinceModifier)

    /// A server extension modifier not defined in this library.
    ///
    /// Captures future `STORE` modifiers defined by extensions, allowing forward compatibility
    /// with new IMAP capabilities without requiring library updates.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeStoreModifiers(_ array: [StoreModifier]) -> Int {
        guard array.count > 0 else {
            return 0
        }

        return self.writeArray(array, prefix: " ", separator: " ", suffix: "", parenthesis: true) { (element, self) in
            self.writeStoreModifier(element)
        }
    }

    @discardableResult mutating func writeStoreModifier(_ val: StoreModifier) -> Int {
        switch val {
        case .unchangedSince(let unchangedSince):
            return self.writeUnchangedSinceModifier(unchangedSince)
        case .other(let param):
            return self.writeParameter(param)
        }
    }
}
