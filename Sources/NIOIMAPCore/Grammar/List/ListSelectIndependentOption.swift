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

/// Selection options for `LIST` commands that do not syntactically interact with other options (RFC 5258 LIST-EXTENDED extension).
///
/// **Requires server capability:** ``Capability/listExtended``
///
/// These options can be freely combined with each other and with ``ListSelectBaseOption``
/// without creating conflicts or ambiguities in the protocol grammar. Unlike ``ListSelectOption``,
/// these options have independent status in the protocol. Independent options are defined in
/// [RFC 5258 Section 3](https://datatracker.ietf.org/doc/html/rfc5258#section-3).
///
/// ### Example
///
/// ```
/// C: A001 LIST SUBSCRIBED (REMOTE SPECIAL-USE) "" "*"
/// S: * LIST (\HasNoChildren \Drafts) "/" "Drafts"
/// S: * LIST (\HasNoChildren \Archive) "/" "Archive"
/// S: A001 OK LIST completed
/// ```
///
/// The command `LIST SUBSCRIBED (REMOTE SPECIAL-USE) "" "*"` uses the independent options
/// ``remote`` and ``specialUse`` to return subscribed remote mailboxes marked with special-use attributes.
///
/// ## Related types
///
/// These differ from ``ListSelectOption`` which may have syntactic relationships.
/// Combine independent options with ``ListSelectBaseOption`` using ``ListSelectOptions``.
///
/// - SeeAlso: [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258), [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)
public enum ListSelectIndependentOption: Hashable, Sendable {
    /// The `REMOTE` independent option returns information about remote mailbox stores.
    ///
    /// Asks the server to include mailboxes from remote mailbox stores in addition
    /// to local mailboxes. From [RFC 5258 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5258#section-3.2).
    case remote

    /// The `SPECIAL-USE` independent option returns only mailboxes with special-use attributes.
    ///
    /// Filters results to mailboxes marked with attributes like `\All`, `\Archive`, `\Drafts`,
    /// `\Flagged`, `\Junk`, `\Sent`, or `\Trash` (from [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)).
    case specialUse

    /// Catch-all for `LIST` independent selection options defined in future extensions.
    ///
    /// Supports extension independent options not yet defined in the standard.
    case option(KeyValue<OptionExtensionKind, OptionValueComp?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectIndependentOption(_ option: ListSelectIndependentOption) -> Int {
        switch option {
        case .remote:
            return self.writeString("REMOTE")
        case .option(let option):
            return self.writeOptionExtension(option)
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        }
    }
}
