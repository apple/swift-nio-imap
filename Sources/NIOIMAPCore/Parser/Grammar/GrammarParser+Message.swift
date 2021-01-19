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
    static func parseMessageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        func parseMessageData_vanished(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("VANISHED ", buffer: &buffer, tracker: tracker)
            return .vanished(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("VANISHED (EARLIER) ", buffer: &buffer, tracker: tracker)
            return .vanishedEarlier(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_genURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("GENURLAUTH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return .genURLAuth(array)
        }

        func parseMessageData_fetchData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("URLFETCH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> URLFetchData in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseURLFetchData(buffer: &buffer, tracker: tracker)
            })
            return .urlFetch(array)
        }

        return try oneOf([
            parseMessageData_expunge,
            parseMessageData_vanished,
            parseMessageData_vanishedEarlier,
            parseMessageData_genURLAuth,
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
    static func parseMessageAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
        func parseMessageAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try fixedString("FLAGS (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Flag in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return .flags(array)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BODY", buffer: &buffer, tracker: tracker)
            let hasExtensionData: Bool = {
                do {
                    try fixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try space(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: hasExtensionData)
        }

        func parseMessageAttribute_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .binary(section: section, data: string)
        }

        func parseMessageAttribute_fetchModifierResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            .fetchModificationResponse(try self.parseFetchModificationResponse(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_gmailMessageID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("X-GM-MSGID", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("X-GM-THRID", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try fixedString("X-GM-LABELS (", buffer: &buffer, tracker: tracker)

            let first: GmailLabel? = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first = first {
                attributes.append(first)

                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &attributes, tracker: tracker) { buffer, tracker in
                    try space(buffer: &buffer, tracker: tracker)
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .gmailLabels(attributes)
        }

        return try oneOf([
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
