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
    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    func parseMessageData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MessageData {
        func parseMessageData_expunge(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageData {
            let number: SequenceNumber = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" EXPUNGE")
            return .expunge(number)
        }

        func parseMessageData_vanished(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageData {
            try buffer.matchFixed("VANISHED ")
            return try .vanished(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageData {
            try buffer.matchFixed("VANISHED (EARLIER) ")
            return try .vanishedEarlier(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_generateAuthorizedURL(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageData {
            try buffer.matchFixed("GENURLAUTH")
            let array = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> [UInt8] in
                    try buffer.parseSpaces()
                    return try self.parseAString(buffer: &buffer, tracker: tracker)
                }
            )
            return .generateAuthorizedURL(array)
        }

        func parseMessageData_fetchData(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageData {
            try buffer.matchFixed("URLFETCH")
            let array = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> URLFetchData in
                    try buffer.parseSpaces()
                    return try self.parseURLFetchData(buffer: &buffer, tracker: tracker)
                }
            )
            return .urlFetch(array)
        }

        let p1 = ParseAlternative<MessageData> { b, t throws(ParseFailure) in
            try parseMessageData_expunge(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<MessageData> { b, t throws(ParseFailure) in
            try parseMessageData_vanished(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<MessageData> { b, t throws(ParseFailure) in
            try parseMessageData_vanishedEarlier(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<MessageData> { b, t throws(ParseFailure) in
            try parseMessageData_generateAuthorizedURL(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<MessageData> { b, t throws(ParseFailure) in
            try parseMessageData_fetchData(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5], tracker: tracker)
    }

    // msg-att-static  = "ENVELOPE" SP envelope / "INTERNALDATE" SP date-time /
    //                   "RFC822.SIZE" SP number /
    //                   "BODY" ["STRUCTURE"] SP body /
    //                   "BODY" section ["<" number ">"] SP nstring /
    //                   "BINARY" section-binary SP (nstring / literal8) /
    //                   "BINARY.SIZE" section-binary SP number /
    //                   "UID" SP uniqueid
    // msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
    // ---- This function combines static and dynamic
    func parseMessageAttribute(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MessageAttribute {
        func parseMessageAttribute_flags(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MessageAttribute in
                try buffer.parseSpaces()
                let flags = try self.parseFlagList(buffer: &buffer, tracker: tracker)
                return .flags(flags)
            }
        }

        func parseMessageAttribute_envelope(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            return try .envelope(self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            return try .internalDate(self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822Size(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            return try .rfc822Size(self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            // `BODY` can either be a body(structure) or a body section:

            func parseMessageAttribute_body_structure(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
                return .body(body, hasExtensionData: false)
            }

            let p1 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_body_structure(buffer: &b, tracker: t)
            }
            let p2 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_bodySection_nilBody(buffer: &b, tracker: t)
            }
            return try buffer.parseOneOf([p1, p2], tracker: tracker)
        }

        func parseMessageAttribute_bodyStructure(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: true)
        }

        func parseMessageAttribute_uid(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            return try .uid(self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_fetchModifierResponse(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> MessageAttribute in
                try buffer.parseSpaces()
                try buffer.matchFixed("(")
                let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                return .fetchModificationSequence(val)
            }
        }

        func parseMessageAttribute_gmailMessageID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try buffer.parseSpaces()
            try buffer.matchFixed("(")

            let first: GmailLabel? = try buffer.parseOptional(tracker: tracker) {
                buffer,
                tracker throws(ParseFailure) in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first {
                attributes.append(first)

                try buffer.parseZeroOrMore(into: &attributes, tracker: tracker) {
                    buffer,
                    tracker throws(ParseFailure) in
                    try buffer.parseSpaces()
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try buffer.matchFixed(")")
            return .gmailLabels(attributes)
        }

        func parseMessageAttribute_rfc822Text_nilBody(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Text(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_rfc822Header_nilBody(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Header(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_bodySection_nilBody(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_bodySectionText(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_binary_nilBody(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_binary(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_preview(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            func parseMessageAttribute_preview_literal(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                let raw = try self.parseLiteral(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(decoding: raw, as: UTF8.self)))
            }

            func parseMessageAttribute_preview_inline(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                let raw = try self.parseQuoted(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(decoding: raw, as: UTF8.self)))
            }

            func parseMessageAttribute_preview_nil(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .preview(nil)
            }

            let p1 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_preview_literal(buffer: &b, tracker: t)
            }
            let p2 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_preview_inline(buffer: &b, tracker: t)
            }
            let p3 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_preview_nil(buffer: &b, tracker: t)
            }
            return try buffer.parseOneOf([p1, p2, p3], tracker: tracker)
        }

        func parseMessageAttribute_emailID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .emailID(EmailID(objectID))
        }

        func parseMessageAttribute_threadID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            func parseMessageAttribute_threadID_objectID(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                try buffer.matchFixed("(")
                let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                return .threadID(ThreadID(objectID))
            }

            func parseMessageAttribute_threadID_nil(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageAttribute {
                try buffer.parseSpaces()
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .threadID(nil)
            }

            let p1 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_threadID_objectID(buffer: &b, tracker: t)
            }
            let p2 = ParseAlternative<MessageAttribute> { b, t throws(ParseFailure) in
                try parseMessageAttribute_threadID_nil(buffer: &b, tracker: t)
            }
            return try buffer.parseOneOf([p1, p2], tracker: tracker)
        }

        func parseMessageAttribute_objectID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageAttribute {
            try buffer.parseSpaces()
            return .objectID(try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker))
        }

        return try self.selectingKeyword(buffer: &buffer) { keyword, buffer throws(ParseFailure) in
            switch keyword {
            case "FLAGS": return try parseMessageAttribute_flags(buffer: &buffer, tracker: tracker)
            case "ENVELOPE": return try parseMessageAttribute_envelope(buffer: &buffer, tracker: tracker)
            case "INTERNALDATE": return try parseMessageAttribute_internalDate(buffer: &buffer, tracker: tracker)
            case "RFC822.SIZE": return try parseMessageAttribute_rfc822Size(buffer: &buffer, tracker: tracker)
            case "BODY": return try parseMessageAttribute_body(buffer: &buffer, tracker: tracker)
            case "BODYSTRUCTURE":
                return try parseMessageAttribute_bodyStructure(buffer: &buffer, tracker: tracker)
            case "UID": return try parseMessageAttribute_uid(buffer: &buffer, tracker: tracker)
            case "BINARY.SIZE": return try parseMessageAttribute_binarySize(buffer: &buffer, tracker: tracker)
            case "X-GM-MSGID":
                return try parseMessageAttribute_gmailMessageID(buffer: &buffer, tracker: tracker)
            case "X-GM-THRID":
                return try parseMessageAttribute_gmailThreadID(buffer: &buffer, tracker: tracker)
            case "X-GM-LABELS":
                return try parseMessageAttribute_gmailLabels(buffer: &buffer, tracker: tracker)
            case "MODSEQ":
                return try parseMessageAttribute_fetchModifierResponse(buffer: &buffer, tracker: tracker)
            case "RFC822.TEXT":
                return try parseMessageAttribute_rfc822Text_nilBody(buffer: &buffer, tracker: tracker)
            case "RFC822.HEADER":
                return try parseMessageAttribute_rfc822Header_nilBody(buffer: &buffer, tracker: tracker)
            case "BINARY":
                return try parseMessageAttribute_binary_nilBody(buffer: &buffer, tracker: tracker)
            case "PREVIEW": return try parseMessageAttribute_preview(buffer: &buffer, tracker: tracker)
            case "EMAILID": return try parseMessageAttribute_emailID(buffer: &buffer, tracker: tracker)
            case "THREADID": return try parseMessageAttribute_threadID(buffer: &buffer, tracker: tracker)
            case "OBJECTID": return try parseMessageAttribute_objectID(buffer: &buffer, tracker: tracker)
            default: throw .mismatch("Not a message-attribute keyword")
            }
        }
    }
}
