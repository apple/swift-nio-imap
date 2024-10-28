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

/// Options to control what is returned as the response of a list command.
public enum ListSelectOption: Hashable, Sendable {
    /// *SUBSCRIBED* - Returns mailboxes that the user has subscribed to
    case subscribed

    /// *REMOTE* - Asks the list response to return both remote and local mailboxes
    case remote

    /// *SPECIAL-USE* - Asks the list response to return special-use mailboxes. E.g. *draft* or *sent* messages.
    case specialUse

    /// *RECURSIVEMATCH* - Forces the server to return information
    /// about parent mailboxes that don't match other selection options,
    /// but have some sub-mailboxes that do.
    case recursiveMatch

    /// Asks the list response to return special-use mailboxes. E.g. *draft* or *sent* messages.
    case option(KeyValue<OptionExtensionKind, OptionValueComp?>)
}

/// Combines an array of `ListSelectOption` with a `ListSelectBaseOption`. Used
/// when performing a `.list` command.
public struct ListSelectOptions: Hashable, Sendable {
    /// The base option to use.
    public var baseOption: ListSelectBaseOption

    /// An array of selection options.
    public var options: [ListSelectOption]

    /// Creates a new `ListSelectOptions`.
    /// - parameter baseOption: The base option to use.
    /// - parameter options: An array of selection options.
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
