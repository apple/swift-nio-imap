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
    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    func parseMessageData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            let number: SequenceNumber = try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" EXPUNGE")
            return .expunge(number)
        }

        func parseMessageData_vanished(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try buffer.matchFixed("VANISHED ")
            return try .vanished(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try buffer.matchFixed("VANISHED (EARLIER) ")
            return try .vanishedEarlier(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_generateAuthorizedURL(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageData {
            try buffer.matchFixed("GENURLAUTH")
            let array = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: { buffer, tracker -> ByteBuffer in
                    try buffer.parseSpaces()
                    return try self.parseAString(buffer: &buffer, tracker: tracker)
                }
            )
            return .generateAuthorizedURL(array)
        }

        func parseMessageData_fetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try buffer.matchFixed("URLFETCH")
            let array = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: { buffer, tracker -> URLFetchData in
                    try buffer.parseSpaces()
                    return try self.parseURLFetchData(buffer: &buffer, tracker: tracker)
                }
            )
            return .urlFetch(array)
        }

        return try buffer.parseOneOf(
            [
                { try parseMessageData_expunge(buffer: &$0, tracker: $1) },
                { try parseMessageData_vanished(buffer: &$0, tracker: $1) },
                { try parseMessageData_vanishedEarlier(buffer: &$0, tracker: $1) },
                { try parseMessageData_generateAuthorizedURL(buffer: &$0, tracker: $1) },
                { try parseMessageData_fetchData(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
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
    func parseMessageAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
        func parseMessageAttribute_flags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try buffer.composite(tracker: tracker) { buffer, tracker -> MessageAttribute in
                try buffer.parseSpaces()
                let flags = try self.parseFlagList(buffer: &buffer, tracker: tracker)
                return .flags(flags)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            try buffer.parseSpaces()
            return try .envelope(self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.parseSpaces()
            return try .internalDate(self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822Size(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.parseSpaces()
            return try .rfc822Size(self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            // `BODY` can either be a body(structure) or a body section:

            func parseMessageAttribute_body_structure(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
                return .body(body, hasExtensionData: false)
            }

            return try buffer.parseOneOf(
                [
                    { try parseMessageAttribute_body_structure(buffer: &$0, tracker: $1) },
                    { try parseMessageAttribute_bodySection_nilBody(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        func parseMessageAttribute_bodyStructure(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.parseSpaces()
            let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: true)
        }

        func parseMessageAttribute_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try buffer.parseSpaces()
            return try .uid(self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_fetchModifierResponse(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.composite(tracker: tracker) { (buffer, tracker) -> MessageAttribute in
                try buffer.parseSpaces()
                try buffer.matchFixed("(")
                let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                return .fetchModificationSequence(val)
            }
        }

        func parseMessageAttribute_gmailMessageID(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.parseSpaces()
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try buffer.parseSpaces()
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try buffer.parseSpaces()
            try buffer.matchFixed("(")

            let first: GmailLabel? = try buffer.parseOptional(tracker: tracker) { buffer, tracker in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first {
                attributes.append(first)

                try buffer.parseZeroOrMore(into: &attributes, tracker: tracker) { buffer, tracker in
                    try buffer.parseSpaces()
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try buffer.matchFixed(")")
            return .gmailLabels(attributes)
        }

        func parseMessageAttribute_rfc822Text_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Text(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_rfc822Header_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Header(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_bodySection_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_bodySectionText(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_binary_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_binary(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_preview(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            func parseMessageAttribute_preview_literal(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                let raw = try self.parseLiteral(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(buffer: raw)))
            }

            func parseMessageAttribute_preview_inline(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                let raw = try self.parseQuoted(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(buffer: raw)))
            }

            func parseMessageAttribute_preview_nil(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .preview(nil)
            }

            return try buffer.parseOneOf(
                [
                    { try parseMessageAttribute_preview_literal(buffer: &$0, tracker: $1) },
                    { try parseMessageAttribute_preview_inline(buffer: &$0, tracker: $1) },
                    { try parseMessageAttribute_preview_nil(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        func parseMessageAttribute_emailID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .emailID(EmailID(objectID))
        }

        func parseMessageAttribute_threadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            func parseMessageAttribute_threadID_objectID(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                try buffer.matchFixed("(")
                let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                return .threadID(ThreadID(objectID))
            }

            func parseMessageAttribute_threadID_nil(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try buffer.parseSpaces()
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .threadID(nil)
            }

            return try buffer.parseOneOf(
                [
                    { try parseMessageAttribute_threadID_objectID(buffer: &$0, tracker: $1) },
                    { try parseMessageAttribute_threadID_nil(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        func parseMessageAttribute_objectID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            try buffer.parseSpaces()
            return .objectID(try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker))
        }

        return try self.selectingKeyword(buffer: &buffer) { keyword, buffer in
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
            default: throw ParserError(hint: "Not a message-attribute keyword")
            }
        }
    }
}
