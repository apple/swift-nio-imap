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
    // response-data   = "*" SP response-payload CRLF
    static func parseResponseData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    static func parseTaggedResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let state = try self.parseTaggedResponseState(buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    static func parseResponseCodeAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseCodeAppend {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeAppend in
            try PL.parseFixedString("APPENDUID ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let uid = try self.parseUID(buffer: &buffer, tracker: tracker)
            return ResponseCodeAppend(num: number, uid: uid)
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    static func parseResponseCodeCopy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseCodeCopy {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeCopy in
            try PL.parseFixedString("COPYUID ", buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let sourceUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let destinationUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            return ResponseCodeCopy(destinationUIDValidity: uidValidity, sourceUIDs: sourceUIDRanges, destinationUIDs: destinationUIDRanges)
        }
    }

    /// This is a combination of `resp-cond-state`, `resp-cond-bye`, and `greeting`.
    static func parseUntaggedResponseStatus(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
        func parseTaggedResponseState_ok(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
            try PL.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_no(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
            try PL.parseFixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_bad(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
            try PL.parseFixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_preAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
            try PL.parseFixedString("PREAUTH ", buffer: &buffer, tracker: tracker)
            return .preauth(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_bye(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
            try PL.parseFixedString("BYE ", buffer: &buffer, tracker: tracker)
            return .bye(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf([
            parseTaggedResponseState_ok,
            parseTaggedResponseState_no,
            parseTaggedResponseState_bad,
            parseTaggedResponseState_preAuth,
            parseTaggedResponseState_bye,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    static func parseTaggedResponseState(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse.State {
        func parseTaggedResponseState_ok(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse.State {
            try PL.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_no(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse.State {
            try PL.parseFixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedResponseState_bad(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse.State {
            try PL.parseFixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseTaggedResponseState_ok,
            parseTaggedResponseState_no,
            parseTaggedResponseState_bad,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // response-payload = resp-cond-state / resp-cond-bye / mailbox-data / message-data / capability-data / id-response / enable-data
    static func parseResponsePayload(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
        func parseResponsePayload_conditionalState(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .conditionalState(try self.parseUntaggedResponseStatus(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_mailboxData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .mailboxData(try self.parseMailboxData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_messageData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .messageData(try self.parseMessageData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_capabilityData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .capabilityData(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_idResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .id(try self.parseIDResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_enableData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .enableData(try self.parseEnableData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_metadata(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .metadata(try self.parseMetadataResponse(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf([
            parseResponsePayload_mailboxData,
            parseResponsePayload_messageData,
            parseResponsePayload_capabilityData,
            parseResponsePayload_idResponse,
            parseResponsePayload_enableData,
            parseResponsePayload_quota,
            parseResponsePayload_quotaRoot,
            parseResponsePayload_metadata,
            parseResponsePayload_conditionalState,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-text       = ["[" resp-text-code "]" SP] text
    static func parseResponseText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseText {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            let code = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ResponseTextCode in
                try PL.parseFixedString("[", buffer: &buffer, tracker: tracker)
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("]", buffer: &buffer, tracker: tracker)
                return code
            }

            // because some servers might not send the text (looking at you, iCloud), they might
            // also not send a space after resp-text-code, so make parsing optional
            try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces)

            // text requires minimum 1 char, but we want to be lenient here
            // and allow 0 characters to represent empty text
            let text = try PL.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                char.isTextChar
            }
            return ResponseText(code: code, text: String(buffer: text))
        }
    }

    // resp-text-code  = "ALERT" /
    //                   "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
    //                   capability-data / "PARSE" /
    //                   "PERMANENTFLAGS" SP "("
    //                   [flag-perm *(SP flag-perm)] ")" /
    //                   "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
    //                   "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
    //                   "UNSEEN" SP nz-number
    //                   atom [SP 1*<any TEXT-CHAR except "]">] /
    //                   "NOTSAVED"
    static func parseResponseTextCode(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        func parseResponseTextCode_alert(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("ALERT", buffer: &buffer, tracker: tracker)
            return .alert
        }

        func parseResponseTextCode_noModifierSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("NOMODSEQ", buffer: &buffer, tracker: tracker)
            return .noModificationSequence
        }

        func parseResponseTextCode_modified(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("MODIFIED ", buffer: &buffer, tracker: tracker)
            return .modificationSequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_highestModifiedSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .highestModificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_referral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("REFERRAL ", buffer: &buffer, tracker: tracker)
            return .referral(try self.parseIMAPURL(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_badCharset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("BADCHARSET", buffer: &buffer, tracker: tracker)
            let charsets = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [String] in
                try PL.parseFixedString(" (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseCharset(buffer: &buffer, tracker: tracker)]
                try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseCharset(buffer: &buffer, tracker: tracker)
                }
                try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            return .badCharset(charsets)
        }

        func parseResponseTextCode_capabilityData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_parse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("PARSE", buffer: &buffer, tracker: tracker)
            return .parse
        }

        func parseResponseTextCode_permanentFlags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("PERMANENTFLAGS (", buffer: &buffer, tracker: tracker)
            let array = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [PermanentFlag] in
                var array = [try self.parseFlagPerm(buffer: &buffer, tracker: tracker)]
                try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagPerm(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .permanentFlags(array ?? [])
        }

        func parseResponseTextCode_readOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("READ-ONLY", buffer: &buffer, tracker: tracker)
            return .readOnly
        }

        func parseResponseTextCode_readWrite(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("READ-WRITE", buffer: &buffer, tracker: tracker)
            return .readWrite
        }

        func parseResponseTextCode_tryCreate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("TRYCREATE", buffer: &buffer, tracker: tracker)
            return .tryCreate
        }

        func parseResponseTextCode_uidNext(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseUIDValidity(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_unseen(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseSequenceNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_namespace(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
                return String(buffer: parsed)
            }
            return .other(atom, string)
        }

        func parseResponseTextCode_uidNotSticky(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("UIDNOTSTICKY", buffer: &buffer, tracker: tracker)
            return .uidNotSticky
        }

        func parseResponseTextCode_closed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("CLOSED", buffer: &buffer, tracker: tracker)
            return .closed
        }

        func parseResponseTextCode_uidCopy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .uidCopy(try self.parseResponseCodeCopy(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .uidAppend(try self.parseResponseCodeAppend(buffer: &buffer, tracker: tracker))
        }

        // RFC 5182
        func parseResponseTextCode_notSaved(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("NOTSAVED", buffer: &buffer, tracker: tracker)
            return .notSaved
        }

        func parseResponseTextCode_metadataLongEntries(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("METADATA LONGENTRIES ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .metadataLongEntries(num)
        }

        func parseResponseTextCode_metadataMaxSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("METADATA MAXSIZE ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .metadataMaxsize(num)
        }

        func parseResponseTextCode_metadataTooMany(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("METADATA TOOMANY", buffer: &buffer, tracker: tracker)
            return .metadataTooMany
        }

        func parseResponseTextCode_metadataNoPrivate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("METADATA NOPRIVATE", buffer: &buffer, tracker: tracker)
            return .metadataNoPrivate
        }

        func parseResponseTextCode_urlMechanisms(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseFixedString("URLMECH INTERNAL", buffer: &buffer, tracker: tracker)
            let array = try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> MechanismBase64 in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMechanismBase64(buffer: &buffer, tracker: tracker)
            })
            return .urlMechanisms(array)
        }

        return try PL.parseOneOf([
            parseResponseTextCode_alert,
            parseResponseTextCode_noModifierSequence,
            parseResponseTextCode_modified,
            parseResponseTextCode_highestModifiedSequence,
            parseResponseTextCode_badCharset,
            parseResponseTextCode_capabilityData,
            parseResponseTextCode_parse,
            parseResponseTextCode_permanentFlags,
            parseResponseTextCode_readOnly,
            parseResponseTextCode_readWrite,
            parseResponseTextCode_tryCreate,
            parseResponseTextCode_uidNext,
            parseResponseTextCode_uidValidity,
            parseResponseTextCode_unseen,
            parseResponseTextCode_namespace,
            parseResponseTextCode_uidNotSticky,
            parseResponseTextCode_notSaved,
            parseResponseTextCode_uidCopy,
            parseResponseTextCode_uidAppend,
            parseResponseTextCode_closed,
            parseResponseTextCode_metadataLongEntries,
            parseResponseTextCode_metadataMaxSize,
            parseResponseTextCode_metadataTooMany,
            parseResponseTextCode_metadataNoPrivate,
            parseResponseTextCode_urlMechanisms,
            parseResponseTextCode_referral,
            parseResponseTextCode_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // quota_response  ::= "QUOTA" SP astring SP quota_list
    static func parseResponsePayload_quota(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
        // quota_resource  ::= atom SP number SP number
        func parseQuotaResource(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaResource {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let usage = try parseNumber(buffer: &buffer, tracker: tracker)
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaResource(resourceName: resourceName, usage: usage, limit: limit)
            }
        }

        // quota_list      ::= "(" #quota_resource ")"
        func parseQuotaList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [QuotaResource] {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
                var resources: [QuotaResource] = []
                while let resource = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parseQuotaResource) {
                    resources.append(resource)
                    if try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces) == nil {
                        break
                    }
                }
                try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return resources
            }
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("QUOTA ", buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseAString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let resources = try parseQuotaList(buffer: &buffer, tracker: tracker)
            return .quota(.init(quotaRoot), resources)
        }
    }

    // quotaroot_response ::= "QUOTAROOT" SP astring *(SP astring)
    static func parseResponsePayload_quotaRoot(buffer: inout ParseBuffer,
                                               tracker: StackTracker) throws -> ResponsePayload
    {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("QUOTAROOT ", buffer: &buffer, tracker: tracker)
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseAString(buffer: &buffer, tracker: tracker)
            return .quotaRoot(mailbox, .init(quotaRoot))
        }
    }
}
