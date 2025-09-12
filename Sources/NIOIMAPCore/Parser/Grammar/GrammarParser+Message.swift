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
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
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
            try PL.parseFixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        func parseMessageData_vanished(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try PL.parseFixedString("VANISHED ", buffer: &buffer, tracker: tracker)
            return try .vanished(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try PL.parseFixedString("VANISHED (EARLIER) ", buffer: &buffer, tracker: tracker)
            return try .vanishedEarlier(self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_generateAuthorizedURL(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageData {
            try PL.parseFixedString("GENURLAUTH", buffer: &buffer, tracker: tracker)
            let array = try PL.parseOneOrMore(
                buffer: &buffer,
                tracker: tracker,
                parser: { buffer, tracker -> ByteBuffer in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseAString(buffer: &buffer, tracker: tracker)
                }
            )
            return .generateAuthorizedURL(array)
        }

        func parseMessageData_fetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try PL.parseFixedString("URLFETCH", buffer: &buffer, tracker: tracker)
            let array = try PL.parseOneOrMore(
                buffer: &buffer,
                tracker: tracker,
                parser: { buffer, tracker -> URLFetchData in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseURLFetchData(buffer: &buffer, tracker: tracker)
                }
            )
            return .urlFetch(array)
        }

        return try PL.parseOneOf(
            [
                parseMessageData_expunge,
                parseMessageData_vanished,
                parseMessageData_vanishedEarlier,
                parseMessageData_generateAuthorizedURL,
                parseMessageData_fetchData,
            ],
            buffer: &buffer,
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
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let flags = try self.parseFlagList(buffer: &buffer, tracker: tracker)
                return .flags(flags)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try .envelope(self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try .internalDate(self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822Size(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try .rfc822Size(self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            // `BODY` can either be a body(structure) or a body section:

            func parseMessageAttribute_body_structure(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
                return .body(body, hasExtensionData: false)
            }

            return try PL.parseOneOf(
                [
                    parseMessageAttribute_body_structure,
                    parseMessageAttribute_bodySection_nilBody,
                ],
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseMessageAttribute_bodyStructure(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let body = try self.parseMessageAttributeBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: true)
        }

        func parseMessageAttribute_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try .uid(self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_fetchModifierResponse(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MessageAttribute in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
                let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return .fetchModificationResponse(.init(modifierSequenceValue: val))
            }
        }

        func parseMessageAttribute_gmailMessageID(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let (id, _) = try PL.parseUnsignedInt64(buffer: &buffer, tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let (id, _) = try PL.parseUnsignedInt64(buffer: &buffer, tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)

            let first: GmailLabel? = try PL.parseOptional(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first {
                attributes.append(first)

                try PL.parseZeroOrMore(buffer: &buffer, into: &attributes, tracker: tracker) { buffer, tracker in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .gmailLabels(attributes)
        }

        func parseMessageAttribute_rfc822Text_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Text(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_rfc822Header_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_rfc822Header(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_bodySection_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_bodySectionText(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_binary_nilBody(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageAttribute {
            let kind = try self.parseFetchStreamingResponse_binary(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return .nilBody(kind)
        }

        func parseMessageAttribute_preview(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            func parseMessageAttribute_preview_literal(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let raw = try self.parseLiteral(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(buffer: raw)))
            }

            func parseMessageAttribute_preview_inline(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let raw = try self.parseQuoted(buffer: &buffer, tracker: tracker)
                return .preview(PreviewText(String(buffer: raw)))
            }

            func parseMessageAttribute_preview_nil(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .preview(nil)
            }

            return try PL.parseOneOf(
                [
                    parseMessageAttribute_preview_literal,
                    parseMessageAttribute_preview_inline,
                    parseMessageAttribute_preview_nil,
                ],
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseMessageAttribute_emailID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .emailID(EmailID(objectID))
        }

        func parseMessageAttribute_threadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute
        {
            func parseMessageAttribute_threadID_objectID(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
                let objectID = try parseObjectID(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return .threadID(ThreadID(objectID))
            }

            func parseMessageAttribute_threadID_nil(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageAttribute {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .threadID(nil)
            }

            return try PL.parseOneOf(
                [
                    parseMessageAttribute_threadID_objectID,
                    parseMessageAttribute_threadID_nil,
                ],
                buffer: &buffer,
                tracker: tracker
            )
        }

        let parsers: [String: (inout ParseBuffer, StackTracker) throws -> MessageAttribute] = [
            "FLAGS": parseMessageAttribute_flags,
            "ENVELOPE": parseMessageAttribute_envelope,
            "INTERNALDATE": parseMessageAttribute_internalDate,
            "RFC822.SIZE": parseMessageAttribute_rfc822Size,
            "BODY": parseMessageAttribute_body,
            "BODYSTRUCTURE": parseMessageAttribute_bodyStructure,
            "UID": parseMessageAttribute_uid,
            "BINARY.SIZE": parseMessageAttribute_binarySize,
            "X-GM-MSGID": parseMessageAttribute_gmailMessageID,
            "X-GM-THRID": parseMessageAttribute_gmailThreadID,
            "X-GM-LABELS": parseMessageAttribute_gmailLabels,
            "MODSEQ": parseMessageAttribute_fetchModifierResponse,
            "RFC822.TEXT": parseMessageAttribute_rfc822Text_nilBody,
            "RFC822.HEADER": parseMessageAttribute_rfc822Header_nilBody,
            "BINARY": parseMessageAttribute_binary_nilBody,
            "PREVIEW": parseMessageAttribute_preview,
            "EMAILID": parseMessageAttribute_emailID,
            "THREADID": parseMessageAttribute_threadID,
        ]
        return try self.parseFromLookupTable(buffer: &buffer, tracker: tracker, parsers: parsers)
    }
}
