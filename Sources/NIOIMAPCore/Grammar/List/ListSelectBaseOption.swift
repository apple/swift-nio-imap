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

/// The primary selection mode for a `LIST` command (RFC 5258 LIST-EXTENDED extension).
///
/// **Requires server capability:** ``Capability/listExtended``
///
/// Base options determine the fundamental filtering mode for the `LIST` command,
/// and are defined in [RFC 5258 Section 3.1](https://datatracker.ietf.org/doc/html/rfc5258#section-3.1).
///
/// ### Example
///
/// ```
/// C: A001 LIST SUBSCRIBED "" "*"
/// S: * LIST (\Noselect) "/" "Archive"
/// S: * LIST (\HasNoChildren) "/" "Drafts"
/// S: A001 OK LIST completed
/// ```
///
/// The command `LIST SUBSCRIBED "" "*"` uses the ``subscribed`` base option to return only subscribed mailboxes.
///
/// ## Related Types
///
/// Combine this with ``ListSelectOption`` values to add additional filtering constraints.
/// See ``ListSelectOptions`` for how to construct a complete set of `LIST` selection options.
///
/// - SeeAlso: [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258)
public enum ListSelectBaseOption: Hashable, Sendable {
    /// The `SUBSCRIBED` base option returns only mailboxes the user has subscribed to.
    ///
    /// This is the primary filtering mode that controls which mailboxes are included in the response.
    /// From [RFC 5258 Section 3.1](https://datatracker.ietf.org/doc/html/rfc5258#section-3.1).
    case subscribed

    /// Catch-all for `LIST` base selection options defined in future extensions.
    ///
    /// Supports extension base options not yet defined in the standard.
    case option(KeyValue<OptionExtensionKind, OptionValueComp?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectBaseOption(_ option: ListSelectBaseOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .option(let option):
            return self.writeOptionExtension(option)
        }
    }

    @discardableResult mutating func writeListSelectBaseOptionQuoted(_ option: ListSelectBaseOption) -> Int {
        self.writeString("\"") + self.writeListSelectBaseOption(option) + self.writeString("\"")
    }
}
