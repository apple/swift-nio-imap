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
    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    static func parseMessageData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            let number = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        func parseMessageData_vanished(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try ParserLibrary.fixedString("VANISHED ", buffer: &buffer, tracker: tracker)
            return .vanished(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try ParserLibrary.fixedString("VANISHED (EARLIER) ", buffer: &buffer, tracker: tracker)
            return .vanishedEarlier(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_generateAuthorizedURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try ParserLibrary.fixedString("GENURLAUTH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return .generateAuthorizedURL(array)
        }

        func parseMessageData_fetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageData {
            try ParserLibrary.fixedString("URLFETCH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> URLFetchData in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseURLFetchData(buffer: &buffer, tracker: tracker)
            })
            return .urlFetch(array)
        }

        return try ParserLibrary.oneOf([
            parseMessageData_expunge,
            parseMessageData_vanished,
            parseMessageData_vanishedEarlier,
            parseMessageData_generateAuthorizedURL,
            parseMessageData_fetchData,
        ], buffer: &buffer, tracker: tracker)
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
    static func parseMessageAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
        func parseMessageAttribute_flags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try ParserLibrary.fixedString("FLAGS", buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let flags = try self.parseFlagList(buffer: &buffer, tracker: tracker)
                return .flags(flags)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822Size(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("BODY", buffer: &buffer, tracker: tracker)
            let hasExtensionData: Bool = {
                do {
                    try ParserLibrary.fixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: hasExtensionData)
        }

        func parseMessageAttribute_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_binary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .binary(section: section, data: string)
        }

        func parseMessageAttribute_fetchModifierResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            .fetchModificationResponse(try self.parseFetchModificationResponse(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_gmailMessageID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("X-GM-MSGID", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.fixedString("X-GM-THRID", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try ParserLibrary.fixedString("X-GM-LABELS (", buffer: &buffer, tracker: tracker)

            let first: GmailLabel? = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first = first {
                attributes.append(first)

                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &attributes, tracker: tracker) { buffer, tracker in
                    try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
            return .gmailLabels(attributes)
        }

        return try ParserLibrary.oneOf([
            parseMessageAttribute_envelope,
            parseMessageAttribute_internalDate,
            parseMessageAttribute_rfc822Size,
            parseMessageAttribute_body,
            parseMessageAttribute_uid,
            parseMessageAttribute_binarySize,
            parseMessageAttribute_binary,
            parseMessageAttribute_flags,
            parseMessageAttribute_fetchModifierResponse,
            parseMessageAttribute_gmailMessageID,
            parseMessageAttribute_gmailThreadID,
            parseMessageAttribute_gmailLabels,
        ], buffer: &buffer, tracker: tracker)
    }
}
