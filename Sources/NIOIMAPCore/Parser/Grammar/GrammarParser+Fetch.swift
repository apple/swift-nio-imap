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
    func parseFetch_type(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
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
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) {
                (buffer, tracker) -> FetchAttribute in
                try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try PL.parseOneOf(
            [
                parseFetch_type_all,
                parseFetch_type_full,
                parseFetch_type_fast,
                parseFetch_type_singleAtt,
                parseFetch_type_multiAtt,
            ],
            buffer: &buffer,
            tracker: tracker
        )
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    func parseFetchAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
        func parseFetchAttribute_bodySection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute
        {
            // Try to parse a section, `[something]`. If this fails, then it's a normal, boring body, without extensions
            // (with extensions is sent as `BODYSTRUCTURE`).
            // This is one of the few cases where we need to explicitly catch the "incompleteMessage" case and *NOT*
            // propogate it forward.
            if let section = try? self.parseSection(buffer: &buffer, tracker: tracker) {
                let chevronNumber = try PL.parseOptional(buffer: &buffer, tracker: tracker) {
                    (buffer, tracker) -> ClosedRange<UInt32> in
                    try self.parsePartial(buffer: &buffer, tracker: tracker)
                }
                return .bodySection(peek: false, section, chevronNumber)
            }
            return .bodyStructure(extensions: false)
        }

        func parseFetchAttribute_bodyPeekSection(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> FetchAttribute {
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try PL.parseOptional(buffer: &buffer, tracker: tracker) {
                (buffer, tracker) -> ClosedRange<UInt32> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modificationSequence(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> FetchAttribute {
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

        func parseFetchAttribute_preview(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchAttribute {
            // RFC 8970
            // fetch-att         =/ "PREVIEW" [SP "(" preview-mod *(SP preview-mod) ")"]
            // preview-mod       =  "LAZY"
            func parsePreviewLazyModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Bool {
                do {
                    try PL.parseFixedString(" (LAZY)", buffer: &buffer, tracker: tracker)
                    return true
                } catch is ParserError {
                    return false
                }
            }

            let lazy = try parsePreviewLazyModifier(buffer: &buffer, tracker: tracker)
            return .preview(lazy: lazy)
        }

        // try to use the keyword, however obviously an unknown number
        // cannot be selected by keyword. If no keyword matches, fall back and try to parse a
        // modification sequence.
        do {
            return try self.selectingKeyword(buffer: &buffer) { keyword, buffer in
                switch keyword {
                case "ENVELOPE": return .envelope
                case "FLAGS": return .flags
                case "INTERNALDATE": return .internalDate
                case "UID": return .uid
                case "MODSEQ": return .modificationSequence
                case "X-GM-MSGID": return .gmailMessageID
                case "X-GM-THRID": return .gmailThreadID
                case "X-GM-LABELS": return .gmailLabels
                case "RFC822.SIZE": return .rfc822Size
                case "RFC822.HEADER": return .rfc822Header
                case "RFC822.TEXT": return .rfc822Text
                case "RFC822": return .rfc822
                case "BODYSTRUCTURE": return .bodyStructure(extensions: true)
                case "BODY": return try parseFetchAttribute_bodySection(buffer: &buffer, tracker: tracker)
                case "BODY.PEEK": return try parseFetchAttribute_bodyPeekSection(buffer: &buffer, tracker: tracker)
                case "BINARY.SIZE": return try parseFetchAttribute_binarySize(buffer: &buffer, tracker: tracker)
                case "BINARY": return try parseFetchAttribute_binary(buffer: &buffer, tracker: tracker)
                case "BINARY.PEEK": return try parseFetchAttribute_binaryPeek(buffer: &buffer, tracker: tracker)
                case "PREVIEW": return try parseFetchAttribute_preview(buffer: &buffer, tracker: tracker)
                case "EMAILID": return .emailID
                case "THREADID": return .threadID
                case "OBJECTID": return .objectID
                default: throw ParserError(hint: "Not a fetch attribute keyword")
                }
            }
        } catch is ParserError {
            return try parseFetchAttribute_modificationSequence(buffer: &buffer, tracker: tracker)
        }
    }

    func parseFetchStreamingResponse_rfc822Text(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> StreamingKind {
        .rfc822Text
    }

    func parseFetchStreamingResponse_rfc822Header(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> StreamingKind {
        .rfc822Header
    }

    func parseFetchStreamingResponse_bodySectionText(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> StreamingKind {
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
        let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
        let offset = try PL.parseOptional(
            buffer: &buffer,
            tracker: tracker,
            parser: { buffer, tracker -> Int in
                try PL.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
        )
        return .binary(section: section, offset: offset)
    }

    func parseFetchStreamingResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StreamingKind {
        try self.selectingKeyword(buffer: &buffer) { keyword, buffer in
            switch keyword {
            case "RFC822.TEXT":
                return try parseFetchStreamingResponse_rfc822Text(buffer: &buffer, tracker: tracker)
            case "RFC822.HEADER":
                return try parseFetchStreamingResponse_rfc822Header(buffer: &buffer, tracker: tracker)
            case "BODY":
                return try parseFetchStreamingResponse_bodySectionText(buffer: &buffer, tracker: tracker)
            case "BINARY":
                return try parseFetchStreamingResponse_binary(buffer: &buffer, tracker: tracker)
            default:
                throw ParserError(hint: "Not a streaming fetch response keyword")
            }
        }
    }

    func parseFetchModifiers(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [FetchModifier] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchModifier(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) {
                buffer,
                tracker -> FetchModifier in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseFetchModifier(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    func parseFetchModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
        func parseFetchModifier_changedSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
            .changedSince(try self.parseChangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_partial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
            try PL.parseFixedString("PARTIAL", buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .partial(try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FetchModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseFetchModifier_changedSince,
            parseFetchModifier_partial,
            parseFetchModifier_other,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseFetchResponseStart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
        func parseFetchResponseStart_normal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try PL.parseFixedString("* ", buffer: &buffer, tracker: tracker)
                let number: SequenceNumber = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(" FETCH (", buffer: &buffer, tracker: tracker)
                return .start(number)
            }
        }

        func parseFetchResponseStart_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try PL.parseFixedString("* ", buffer: &buffer, tracker: tracker)
                let number: UID = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(" UIDFETCH (", buffer: &buffer, tracker: tracker)
                return .startUID(number)
            }
        }

        return try PL.parseOneOf(
            [
                parseFetchResponseStart_normal,
                parseFetchResponseStart_uid,
            ],
            buffer: &buffer,
            tracker: tracker
        )
    }

    // needed to tell the response parser which type of streaming is
    // going to take place, e.g. quoted or literal
    enum _FetchResponse: Hashable {
        case start(SequenceNumber)
        case startUID(UID)
        case simpleAttribute(MessageAttribute)
        case literalStreamingBegin(kind: StreamingKind, byteCount: Int)
        case quotedStreamingBegin(kind: StreamingKind, byteCount: Int)
        case finish
    }

    func parseFetchResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _FetchResponse {
        func parseFetchResponse_simpleAttribute(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> _FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(
                buffer: &buffer,
                tracker: tracker,
                maxLength: self.messageBodySizeLimit
            )
            return .literalStreamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_streamingBeginQuoted(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> _FetchResponse {
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

        return try PL.parseOneOf(
            [
                parseFetchResponse_streamingBegin,
                parseFetchResponse_streamingBeginQuoted,
                parseFetchResponse_simpleAttribute,
                parseFetchResponse_finish,
            ],
            buffer: &buffer,
            tracker: tracker
        )
    }
}
