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
    static func parseFetch_type(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
        func parseFetch_type_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try PL.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope]
        }

        func parseFetch_type_fast(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try PL.parseFixedString("FAST", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size]
        }

        func parseFetch_type_full(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try PL.parseFixedString("FULL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
        }

        func parseFetch_type_singleAtt(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
        }

        func parseFetch_type_multiAtt(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchAttribute in
                try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try PL.parseOneOf([
            parseFetch_type_all,
            parseFetch_type_full,
            parseFetch_type_fast,
            parseFetch_type_singleAtt,
            parseFetch_type_multiAtt,
        ], buffer: &buffer, tracker: tracker)
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    static func parseFetchAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
        func parseFetchAttribute_bodySection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            
            // Try to parse a section, `[something]`. If this fails, then it's a normal, boring body, without extensions
            // (with extensions is sent as `BODYSTRUCTURE`).
            // This is one of the few cases where we need to explicitly catch the "incompleteMessage" case and *NOT*
            // propogate it forward.
            if let section = try? self.parseSection(buffer: &buffer, tracker: tracker) {
                let chevronNumber = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
                    try self.parsePartial(buffer: &buffer, tracker: tracker)
                }
                return .bodySection(peek: false, section, chevronNumber)
            }
            return .bodyStructure(extensions: false)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            .modificationSequenceValue(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: false, section: sectionBinary, partial: partial)
        }
        
        func parseFetchAttribute_binaryPeek(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: true, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        let parsers: [String: (inout ParseBuffer, StackTracker) throws -> FetchAttribute] = [
            "ENVELOPE": {_, _ in .envelope},
            "FLAGS": {_, _ in .flags},
            "INTERNALDATE": {_, _ in .internalDate},
            "UID": {_, _ in .uid},
            "MODSEQ": {_, _ in .modificationSequence},
            "X-GM-MSGID": {_, _ in .gmailMessageID},
            "X-GM-THRID": {_, _ in .gmailThreadID},
            "X-GM-LABELS": {_, _ in .gmailLabels},
            "RFC822.SIZE": {_, _ in .rfc822Size},
            "RFC822.HEADER": {_, _ in .rfc822Header},
            "RFC822.TEXT": {_, _ in .rfc822Text},
            "RFC822": {_, _ in .rfc822},
            "BODYSTRUCTURE": {_, _ in .bodyStructure(extensions: true)},
            
            "BODY": parseFetchAttribute_bodySection,
            "BODY.PEEK": parseFetchAttribute_bodyPeekSection,
            "BINARY.SIZE": parseFetchAttribute_binarySize,
            "BINARY": parseFetchAttribute_binary,
            "BINARY.PEEK": parseFetchAttribute_binaryPeek
        ]
        
        // try to use the lookup table, however obviously an unknown number
        // cannot be parsed using a lookup table. If the lookup table fails,
        // fall back and try to parse a modification sequence.
        do {
            return try self.parseFromLookupTable(buffer: &buffer, tracker: tracker, parsers: parsers)
        } catch is ParserError {
            return try PL.parseOneOf([
                parseFetchAttribute_modificationSequence,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    static func parseFetchStreamingResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
        func parseFetchStreamingResponse_rfc822Text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try PL.parseFixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
            return .rfc822Text
        }

        func parseFetchStreamingResponse_rfc822Header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try PL.parseFixedString("RFC822.HEADER", buffer: &buffer, tracker: tracker)
            return .rfc822Header
        }

        func parseFetchStreamingResponse_bodySectionText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try PL.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSection) ?? .init()
            let offset = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try PL.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            return .body(section: section, offset: offset)
        }

        func parseFetchStreamingResponse_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try PL.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let offset = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try PL.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            })
            return .binary(section: section, offset: offset)
        }

        return try PL.parseOneOf([
            parseFetchStreamingResponse_rfc822Text,
            parseFetchStreamingResponse_rfc822Header,
            parseFetchStreamingResponse_bodySectionText,
            parseFetchStreamingResponse_binary,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
        func parseFetchModifier_changedSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
            .changedSince(try self.parseChangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseFetchModifier_changedSince,
            parseFetchModifier_other,
            buffer: &buffer,
            tracker: tracker
        )
    }

    static func parseFetchResponseStart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let number = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" FETCH (", buffer: &buffer, tracker: tracker)
            return .start(number)
        }
    }

    // needed to tell the response parser which type of streaming is
    // going to take place, e.g. quoted or literal
    enum _FetchResponse: Equatable {
        case start(SequenceNumber)
        case simpleAttribute(MessageAttribute)
        case literalStreamingBegin(kind: StreamingKind, byteCount: Int)
        case quotedStreamingBegin(kind: StreamingKind, byteCount: Int)
        case finish
    }

    static func parseFetchResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
        func parseFetchResponse_simpleAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .literalStreamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_streamingBeginQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let save = buffer
            let quoted = try self.parseQuoted(buffer: &buffer, tracker: tracker)
            buffer = save
            return .quotedStreamingBegin(kind: type, byteCount: quoted.readableBytes)
        }

        func parseFetchResponse_finish(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return .finish
        }

        return try PL.parseOneOf([
            parseFetchResponse_streamingBegin,
            parseFetchResponse_streamingBeginQuoted,
            parseFetchResponse_simpleAttribute,
            parseFetchResponse_finish,
        ], buffer: &buffer, tracker: tracker)
    }
}
