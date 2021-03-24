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
            try self.fixedString("ALL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope]
        }

        func parseFetch_type_fast(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try self.fixedString("FAST", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size]
        }

        func parseFetch_type_full(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try self.fixedString("FULL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
        }

        func parseFetch_type_singleAtt(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
        }

        func parseFetch_type_multiAtt(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try self.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchAttribute in
                try self.fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try self.oneOf([
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
        func parseFetchAttribute_envelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("ENVELOPE", buffer: &buffer, tracker: tracker)
            return .envelope
        }

        func parseFetchAttribute_flags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("FLAGS", buffer: &buffer, tracker: tracker)
            return .flags
        }

        func parseFetchAttribute_internalDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("INTERNALDATE", buffer: &buffer, tracker: tracker)
            return .internalDate
        }

        func parseFetchAttribute_UID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("UID", buffer: &buffer, tracker: tracker)
            return .uid
        }

        func parseFetchAttribute_rfc822(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parseFetchAttribute_rfc822Size(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try self.fixedString("RFC822.SIZE", buffer: &buffer, tracker: tracker)
                return .rfc822Size
            }

            func parseFetchAttribute_rfc822Header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try self.fixedString("RFC822.HEADER", buffer: &buffer, tracker: tracker)
                return .rfc822Header
            }

            func parseFetchAttribute_rfc822Text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try self.fixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
                return .rfc822Text
            }

            func parseFetchAttribute_rfc822(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try self.fixedString("RFC822", buffer: &buffer, tracker: tracker)
                return .rfc822
            }

            return try self.oneOf([
                parseFetchAttribute_rfc822Size,
                parseFetchAttribute_rfc822Header,
                parseFetchAttribute_rfc822Text,
                parseFetchAttribute_rfc822,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseFetchAttribute_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("BODY", buffer: &buffer, tracker: tracker)
            let extensions: Bool = {
                do {
                    try self.fixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            return .bodyStructure(extensions: extensions)
        }

        func parseFetchAttribute_bodySection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: false, section, chevronNumber)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("BODY.PEEK", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            .modificationSequenceValue(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parsePeek(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Bool {
                let save = buffer
                do {
                    try self.fixedString(".PEEK", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    buffer = save
                    return false
                }
            }

            try self.fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let peek = try parsePeek(buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: peek, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        func parseFetchAttribute_gmailMessageID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("X-GM-MSGID", buffer: &buffer, tracker: tracker)
            return .gmailMessageID
        }

        func parseFetchAttribute_gmailThreadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("X-GM-THRID", buffer: &buffer, tracker: tracker)
            return .gmailThreadID
        }

        func parseFetchAttribute_gmailLabels(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("X-GM-LABELS", buffer: &buffer, tracker: tracker)
            return .gmailLabels
        }

        func parseFetchAttribute_modSeq(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try self.fixedString("MODSEQ", buffer: &buffer, tracker: tracker)
            return .modificationSequence
        }

        return try self.oneOf([
            parseFetchAttribute_envelope,
            parseFetchAttribute_flags,
            parseFetchAttribute_internalDate,
            parseFetchAttribute_UID,
            parseFetchAttribute_rfc822,
            parseFetchAttribute_bodySection,
            parseFetchAttribute_bodyPeekSection,
            parseFetchAttribute_body,
            parseFetchAttribute_modificationSequence,
            parseFetchAttribute_binary,
            parseFetchAttribute_binarySize,
            parseFetchAttribute_gmailMessageID,
            parseFetchAttribute_gmailThreadID,
            parseFetchAttribute_gmailLabels,
            parseFetchAttribute_modSeq,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchModificationResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModificationResponse {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> FetchModificationResponse in
            try self.fixedString("MODSEQ (", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(modifierSequenceValue: val)
        }
    }

    static func parseFetchStreamingResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
        func parseFetchStreamingResponse_rfc822Text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try self.fixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
            return .rfc822Text
        }

        func parseFetchStreamingResponse_rfc822Header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try self.fixedString("RFC822.HEADER", buffer: &buffer, tracker: tracker)
            return .rfc822Header
        }

        func parseFetchStreamingResponse_bodySectionText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try self.fixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseSection) ?? .init()
            let offset = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try self.fixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try self.fixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            return .body(section: section, offset: offset)
        }

        func parseFetchStreamingResponse_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
            try self.fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let offset = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try self.fixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try self.fixedString(">", buffer: &buffer, tracker: tracker)
                return num
            })
            return .binary(section: section, offset: offset)
        }

        return try self.oneOf([
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

        return try self.oneOf([
            parseFetchModifier_changedSince,
            parseFetchModifier_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchResponseStart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("* ", buffer: &buffer, tracker: tracker)
            let number = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            try self.fixedString(" FETCH (", buffer: &buffer, tracker: tracker)
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
            try self.parseSpaces(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .literalStreamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_streamingBeginQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try self.parseSpaces(buffer: &buffer, tracker: tracker)
            let save = buffer
            let quoted = try self.parseQuoted(buffer: &buffer, tracker: tracker)
            buffer = save
            return .quotedStreamingBegin(kind: type, byteCount: quoted.readableBytes)
        }

        func parseFetchResponse_finish(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            try self.newline(buffer: &buffer, tracker: tracker)
            return .finish
        }

        return try self.oneOf([
            parseFetchResponse_streamingBegin,
            parseFetchResponse_streamingBeginQuoted,
            parseFetchResponse_simpleAttribute,
            parseFetchResponse_finish,
        ], buffer: &buffer, tracker: tracker)
    }
}
