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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.fixedString("LIST", buffer: &buffer, tracker: tracker)
            let selectOptions = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOptions in
                try ParserLibrary.space(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.space(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                try ParserLibrary.space(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, reference: mailbox, mailboxPatterns, returnOptions)
        }
    }

    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    static func parseListSelectBaseOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        func parseListSelectBaseOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            try ParserLibrary.fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.oneOf([
            parseListSelectBaseOption_subscribed,
            parseListSelectBaseOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    static func parseListSelectBaseOptionQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListSelectBaseOption in
            try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    static func parseListSelectIndependentOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
        func parseListSelectIndependentOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            try ParserLibrary.fixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.oneOf([
            parseListSelectIndependentOption_subscribed,
            parseListSelectIndependentOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    static func parseListSelectOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
        func parseListSelectOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try ParserLibrary.fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectOption_remote(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try ParserLibrary.fixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectOption_recursiveMatch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try ParserLibrary.fixedString("RECURSIVEMATCH", buffer: &buffer, tracker: tracker)
            return .recursiveMatch
        }

        func parseListSelectOption_specialUse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try ParserLibrary.fixedString("SPECIAL-USE", buffer: &buffer, tracker: tracker)
            return .specialUse
        }

        func parseListSelectOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.oneOf([
            parseListSelectOption_subscribed,
            parseListSelectOption_remote,
            parseListSelectOption_recursiveMatch,
            parseListSelectOption_specialUse,
            parseListSelectOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    static func parseListSelectOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOptions {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.fixedString("(", buffer: &buffer, tracker: tracker)
            var selectOptions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.space(buffer: &buffer, tracker: tracker)
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &selectOptions, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.space(buffer: &buffer, tracker: tracker)
                return option
            }
            try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(baseOption: baseOption, options: selectOptions)
        }
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    static func parseListReturnOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ReturnOption] {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.fixedString("RETURN (", buffer: &buffer, tracker: tracker)
            let options = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ReturnOption in
                    try ParserLibrary.space(buffer: &buffer, tracker: tracker)
                    return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
            return options ?? []
        }
    }

    // list-mailbox    = 1*list-char / string
    static func parseListMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseListMailbox_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseListMailbox_chars(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isListChar
            }
        }

        return try ParserLibrary.oneOf([
            parseListMailbox_string,
            parseListMailbox_chars,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-wildcards  = "%" / "*"
    static func parseListWildcards(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let char = try ParserLibrary.parseByte(buffer: &buffer, tracker: tracker)
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }
}
