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

extension GrammarParser {
    func parseFetch_type(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [FetchAttribute] {
        func parseFetch_type_all(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [FetchAttribute] {
            try buffer.matchFixed("ALL")
            return [.flags, .internalDate, .rfc822Size, .envelope]
        }

        func parseFetch_type_fast(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [FetchAttribute] {
            try buffer.matchFixed("FAST")
            return [.flags, .internalDate, .rfc822Size]
        }

        func parseFetch_type_full(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [FetchAttribute] {
            try buffer.matchFixed("FULL")
            return [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
        }

        func parseFetch_type_singleAtt(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [FetchAttribute] {
            [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
        }

        func parseFetch_type_multiAtt(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [FetchAttribute] {
            try buffer.matchFixed("(")
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> FetchAttribute in
                try buffer.matchFixed(" ")
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }

        let p1 = ParseAlternative<[FetchAttribute]> { b, t throws(ParseFailure) in
            try parseFetch_type_all(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<[FetchAttribute]> { b, t throws(ParseFailure) in
            try parseFetch_type_full(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<[FetchAttribute]> { b, t throws(ParseFailure) in
            try parseFetch_type_fast(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<[FetchAttribute]> { b, t throws(ParseFailure) in
            try parseFetch_type_singleAtt(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<[FetchAttribute]> { b, t throws(ParseFailure) in
            try parseFetch_type_multiAtt(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5], tracker: tracker)
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    func parseFetchAttribute(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FetchAttribute {
        func parseFetchAttribute_bodySection(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            // Try to parse a section, `[something]`. If this fails, then it's a normal, boring body, without extensions
            // (with extensions is sent as `BODYSTRUCTURE`).
            // This is one of the few cases where we need to explicitly catch the "incompleteMessage" case and *NOT*
            // propogate it forward.
            let section: SectionSpecifier?
            do {
                section = try self.parseSection(buffer: &buffer, tracker: tracker)
            } catch .noForwardProgress(let error) {
                throw .noForwardProgress(error)
            } catch {
                section = nil
            }
            if let section {
                let chevronNumber = try buffer.parseOptional(tracker: tracker) {
                    (buffer, tracker) throws(ParseFailure) -> ClosedRange<UInt32> in
                    try self.parsePartial(buffer: &buffer, tracker: tracker)
                }
                return .bodySection(peek: false, section, chevronNumber)
            }
            return .bodyStructure(extensions: false)
        }

        func parseFetchAttribute_bodyPeekSection(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ClosedRange<UInt32> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modificationSequence(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            .modificationSequenceValue(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try buffer.parseOptional(tracker: tracker, parser: self.parsePartial)
            return .binary(peek: false, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binaryPeek(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try buffer.parseOptional(tracker: tracker, parser: self.parsePartial)
            return .binary(peek: true, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        func parseFetchAttribute_preview(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchAttribute {
            // RFC 8970
            // fetch-att         =/ "PREVIEW" [SP "(" preview-mod *(SP preview-mod) ")"]
            // preview-mod       =  "LAZY"
            func parsePreviewLazyModifier(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> Bool {
                do {
                    try buffer.matchFixed(" (LAZY)")
                    return true
                } catch .mismatch {
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
            return try self.selectingKeyword(buffer: &buffer) { keyword, buffer throws(ParseFailure) in
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
                default: throw .mismatch("Not a fetch attribute keyword")
                }
            }
        } catch .mismatch {
            return try parseFetchAttribute_modificationSequence(buffer: &buffer, tracker: tracker)
        }
    }

    func parseFetchStreamingResponse_rfc822Text(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StreamingKind {
        .rfc822Text
    }

    func parseFetchStreamingResponse_rfc822Header(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StreamingKind {
        .rfc822Header
    }

    func parseFetchStreamingResponse_bodySectionText(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StreamingKind {
        let section = try buffer.parseOptional(tracker: tracker, parser: self.parseSection) ?? .init()
        let offset = try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> Int in
            try buffer.matchFixed("<")
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(">")
            return num
        }
        return .body(section: section, offset: offset)
    }

    func parseFetchStreamingResponse_binary(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StreamingKind {
        let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
        let offset = try buffer.parseOptional(
            tracker: tracker,
            parser: { buffer, tracker throws(ParseFailure) -> Int in
                try buffer.matchFixed("<")
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(">")
                return num
            }
        )
        return .binary(section: section, offset: offset)
    }

    func parseFetchStreamingResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StreamingKind {
        try self.selectingKeyword(buffer: &buffer) { keyword, buffer throws(ParseFailure) in
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
                throw .mismatch("Not a streaming fetch response keyword")
            }
        }
    }

    func parseFetchModifiers(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [FetchModifier] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseFetchModifier(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                buffer,
                tracker throws(ParseFailure) -> FetchModifier in
                try buffer.parseSpaces()
                return try self.parseFetchModifier(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseFetchModifier(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FetchModifier {
        func parseFetchModifier_changedSince(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchModifier {
            .changedSince(try self.parseChangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_partial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchModifier {
            try buffer.matchFixed("PARTIAL")
            try buffer.parseSpaces()
            return .partial(try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> FetchModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseFetchModifier_changedSince(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseFetchModifier_partial(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseFetchModifier_other(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseFetchResponseStart(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> _FetchResponse {
        func parseFetchResponseStart_normal(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed("* ")
                let number: SequenceNumber = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(" FETCH (")
                return .start(number)
            }
        }

        func parseFetchResponseStart_uid(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed("* ")
                let number: UID = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(" UIDFETCH (")
                return .startUID(number)
            }
        }

        let p1 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponseStart_normal(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponseStart_uid(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2], tracker: tracker)
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

    func parseFetchResponse(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> _FetchResponse {
        func parseFetchResponse_simpleAttribute(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let literalSize = try self.parseLiteralSize(
                buffer: &buffer,
                tracker: tracker,
                maxLength: self.messageBodySizeLimit
            )
            return .literalStreamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_streamingBeginQuoted(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let save = buffer
            let quoted = try self.parseQuoted(buffer: &buffer, tracker: tracker)
            buffer = save
            return .quotedStreamingBegin(kind: type, byteCount: quoted.count)
        }

        func parseFetchResponse_finish(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> _FetchResponse {
            try buffer.matchFixed(")")
            try buffer.matchNewline()
            return .finish
        }

        let p1 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponse_streamingBegin(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponse_streamingBeginQuoted(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponse_simpleAttribute(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<_FetchResponse> { b, t throws(ParseFailure) in
            try parseFetchResponse_finish(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4], tracker: tracker)
    }
}
