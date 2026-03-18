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

/// A selection option for the `LIST` command (RFC 5258 LIST-EXTENDED extension).
///
/// **Requires server capability:** ``Capability/listExtended``
///
/// These options can be combined with a ``ListSelectBaseOption`` to filter mailboxes
/// according to various criteria. The base `LIST` command is defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501),
/// but selection options are an extension from [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258).
///
/// ### Example
///
/// ```
/// C: A001 LIST (SUBSCRIBED) "" "*"
/// S: * LIST (\Noselect \HasChildren) "/" "archive"
/// S: * LIST (\HasNoChildren) "/" "drafts"
/// S: A001 OK LIST completed
/// ```
///
/// The command `LIST (SUBSCRIBED) "" "*"` uses the ``subscribed`` selection option to return only subscribed mailboxes.
/// The resulting responses wrap mailbox information in ``Response/untagged(_:)`` cases.
///
/// ## Related Types
///
/// Use ``ListSelectBaseOption`` for options that control the basic filtering mode,
/// ``ListSelectIndependentOption`` for options that don't interact syntactically with other options,
/// and ``ListSelectOptions`` to combine base and selection options together.
///
/// - SeeAlso: [RFC 5258](https://datatracker.ietf.org/doc/html/rfc5258), [RFC 6154 Section 2.1](https://datatracker.ietf.org/doc/html/rfc6154#section-2.1)
public enum ListSelectOption: Hashable, Sendable {
    /// The `SUBSCRIBED` selection option returns only mailboxes that the user has subscribed to.
    ///
    /// This option filters the mailbox list to show subscription state rather than all mailboxes.
    /// From [RFC 5258 Section 3.1](https://datatracker.ietf.org/doc/html/rfc5258#section-3.1).
    case subscribed

    /// The `REMOTE` selection option requests mailbox information from remote mailbox stores.
    ///
    /// This is used to include both remote and local mailboxes in the response.
    /// From [RFC 5258 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5258#section-3.2).
    case remote

    /// The `SPECIAL-USE` selection option returns only mailboxes with special-use attributes.
    ///
    /// This filters results to mailboxes marked with attributes like `\All`, `\Archive`, `\Drafts`,
    /// `\Flagged`, `\Junk`, `\Sent`, or `\Trash` (from [RFC 6154](https://datatracker.ietf.org/doc/html/rfc6154)).
    case specialUse

    /// The `RECURSIVEMATCH` selection option returns parent mailboxes that match criteria through their children.
    ///
    /// When specified with other selection criteria, the server returns not just mailboxes that directly
    /// match the criteria, but also their parent mailboxes, even if the parents don't directly match.
    /// From [RFC 5258 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5258#section-3.3).
    case recursiveMatch

    /// Catch-all for `LIST` selection options defined in future extensions.
    ///
    /// Supports extension selection options not yet defined in the standard.
    case option(KeyValue<OptionExtensionKind, OptionValueComp?>)
}

/// A combination of base and selection options for a `LIST` command (RFC 5258 LIST-EXTENDED extension).
///
/// **Requires server capability:** ``Capability/listExtended``
///
/// This structure represents the complete set of selection options for a `LIST` command,
/// combining a base mode with additional filtering criteria. The base option determines
/// the primary filtering mode, while the selection options provide additional constraints.
public struct ListSelectOptions: Hashable, Sendable {
    /// The base selection mode for the `LIST` command.
    ///
    /// The base option determines the primary filtering behavior (typically `SUBSCRIBED`).
    /// See ``ListSelectBaseOption`` for available modes.
    public var baseOption: ListSelectBaseOption

    /// Additional selection criteria to apply.
    ///
    /// These options further constrain which mailboxes are returned. Multiple options
    /// can be combined (e.g., both ``ListSelectOption/remote`` and ``ListSelectOption/specialUse``
    /// to get remote special-use mailboxes).
    public var options: [ListSelectOption]

    /// Creates a new combination of `LIST` selection options.
    ///
    /// - Parameters:
    ///   - baseOption: The base selection mode (e.g., ``ListSelectBaseOption/subscribed``)
    ///   - options: Additional selection criteria to apply
    public init(baseOption: ListSelectBaseOption, options: [ListSelectOption]) {
        self.baseOption = baseOption
        self.options = options
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectOption(_ option: ListSelectOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .recursiveMatch:
            return self.writeString("RECURSIVEMATCH")
        case .remote:
            return self.writeString("REMOTE")
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        case .option(let option):
            return self.writeOptionExtension(option)
        }
    }

    @discardableResult mutating func writeListSelectOptions(_ options: ListSelectOptions?) -> Int {
        self.writeString("(")
            + self.writeIfExists(options) { (optionsData) -> Int in
                self.writeArray(optionsData.options, separator: "", parenthesis: false) { (option, self) -> Int in
                    self.writeListSelectOption(option) + self.writeSpace()
                } + self.writeListSelectBaseOption(optionsData.baseOption)
            } + self.writeString(")")
    }
}
