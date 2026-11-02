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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    func parseListSelectBaseOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        func parseListSelectBaseOption_subscribed(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectBaseOption {
            try buffer.matchFixed("SUBSCRIBED")
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectBaseOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseListSelectBaseOption_subscribed(buffer: &$0, tracker: $1) },
            { try parseListSelectBaseOption_optionExtension(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    func parseListSelectBaseOptionQuoted(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ListSelectBaseOption {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ListSelectBaseOption in
            try buffer.matchFixed("\"")
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("\"")
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    func parseListSelectIndependentOption(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ListSelectIndependentOption {
        func parseListSelectIndependentOption_subscribed(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectIndependentOption {
            try buffer.matchFixed("REMOTE")
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectIndependentOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseListSelectIndependentOption_subscribed(buffer: &$0, tracker: $1) },
            { try parseListSelectIndependentOption_optionExtension(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    func parseListSelectOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
        func parseListSelectOption_subscribed(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectOption {
            try buffer.matchFixed("SUBSCRIBED")
            return .subscribed
        }

        func parseListSelectOption_remote(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try buffer.matchFixed("REMOTE")
            return .remote
        }

        func parseListSelectOption_recursiveMatch(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectOption {
            try buffer.matchFixed("RECURSIVEMATCH")
            return .recursiveMatch
        }

        func parseListSelectOption_specialUse(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectOption {
            try buffer.matchFixed("SPECIAL-USE")
            return .specialUse
        }

        func parseListSelectOption_optionExtension(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ListSelectOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseListSelectOption_subscribed(buffer: &$0, tracker: $1) },
                { try parseListSelectOption_remote(buffer: &$0, tracker: $1) },
                { try parseListSelectOption_recursiveMatch(buffer: &$0, tracker: $1) },
                { try parseListSelectOption_specialUse(buffer: &$0, tracker: $1) },
                { try parseListSelectOption_optionExtension(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    func parseListSelectOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ListSelectOptions {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed("(")
            var selectOptions = try buffer.parseZeroOrMore(tracker: tracker) {
                (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try buffer.parseZeroOrMore(into: &selectOptions, tracker: tracker) {
                (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                return option
            }
            try buffer.matchFixed(")")
            return .init(baseOption: baseOption, options: selectOptions)
        }
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    func parseListReturnOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ReturnOption] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed("RETURN (")
            let options = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> [ReturnOption] in
                var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
                try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                    (buffer, tracker) -> ReturnOption in
                    try buffer.parseSpaces()
                    return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try buffer.matchFixed(")")
            return options ?? []
        }
    }

    // list-mailbox    = 1*list-char / string
    func parseListMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseListMailbox_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseListMailbox_chars(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try buffer.parseOneOrMoreCharacters { char -> Bool in
                char.isListChar
            }
        }

        return try buffer.parseOneOf(
            { try parseListMailbox_string(buffer: &$0, tracker: $1) },
            { try parseListMailbox_chars(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // list-wildcards  = "%" / "*"
    func parseListWildcards(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let char = try buffer.readByte()
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }
}
