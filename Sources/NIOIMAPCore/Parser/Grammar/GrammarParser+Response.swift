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
    func parseResponseData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    func parseTaggedResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let state = try self.parseTaggedResponseState(buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    func parseSuffix_appendUID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseTextCode in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let number = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let uids = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
            return .uidAppend(ResponseCodeAppend(uidValidity: number, uids: uids))
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    func parseSuffix_uidCopy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseTextCode in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let sourceUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let destinationUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            return .uidCopy(ResponseCodeCopy(destinationUIDValidity: uidValidity, sourceUIDs: sourceUIDRanges, destinationUIDs: destinationUIDRanges))
        }
    }

    /// This is a combination of `resp-cond-state`, `resp-cond-bye`, and `greeting`.
    func parseUntaggedResponseStatus(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UntaggedStatus {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let code = try self.parseAtom(buffer: &buffer, tracker: tracker)

            let parsedSpace: Bool
            do {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                parsedSpace = true
            } catch is ParserError {
                parsedSpace = false
            }

            // we should always be able to parse a space
            // but, cough, iCloud and Oracle, sometimes doesn't bother sending
            // a response text.
            let responseText: ResponseText
            if parsedSpace {
                responseText = try self.parseResponseText(buffer: &buffer, tracker: tracker)
            } else {
                responseText = .init(code: nil, text: "")
            }

            guard let state = UntaggedStatus(code: code, responseText: responseText) else {
                throw ParserError(hint: "Invalid response code: \(code)")
            }
            return state
        }
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    func parseTaggedResponseState(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedResponse.State {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let code = try self.parseAtom(buffer: &buffer, tracker: tracker)

            let parsedSpace: Bool
            do {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                parsedSpace = true
            } catch is ParserError {
                parsedSpace = false
            }

            // we should always be able to parse a space
            // but, cough, iCloud and Oracle, sometimes doesn't bother sending
            // a response text.
            let responseText: ResponseText
            if parsedSpace {
                responseText = try self.parseResponseText(buffer: &buffer, tracker: tracker)
            } else {
                responseText = .init(code: nil, text: "")
            }

            guard let state = TaggedResponse.State(code: code, responseText: responseText) else {
                throw ParserError(hint: "Invalid response code: \(code)")
            }
            return state
        }
    }

    // response-payload = resp-cond-state / resp-cond-bye / mailbox-data / message-data / capability-data / id-response / enable-data
    func parseResponsePayload(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
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
    func parseResponseText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseText {
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
            let parsed = try PL.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                char.isTextChar
            }

            let text = try ParserLibrary.parseBufferAsUTF8(parsed)
            return ResponseText(code: code, text: text)
        }
    }

    /// See https://www.iana.org/assignments/imap-response-codes/imap-response-codes.xhtml
    func parseResponseTextCode(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        func parseSuffix_modified(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .modified(try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_highestModifiedSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .highestModificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_referral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .referral(try self.parseIMAPURL(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_badCharset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
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

        func parseSuffix_capability(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilitySuffix(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_permanentFlags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
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

        func parseSuffix_uidNext(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_uidValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseUIDValidity(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_unseen(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_metadata(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            func parseSuffix_metadataLongEntries(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
                try PL.parseFixedString("LONGENTRIES ", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                return .metadataLongEntries(num)
            }

            func parseSuffix_metadataMaxSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
                try PL.parseFixedString("MAXSIZE ", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                return .metadataMaxsize(num)
            }

            func parseSuffix_metadataTooMany(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
                try PL.parseFixedString("TOOMANY", buffer: &buffer, tracker: tracker)
                return .metadataTooMany
            }

            func parseSuffix_metadataNoPrivate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
                try PL.parseFixedString("NOPRIVATE", buffer: &buffer, tracker: tracker)
                return .metadataNoPrivate
            }

            try PL.parseSpaces(buffer: &buffer, tracker: tracker)

            return try PL.parseOneOf([
                parseSuffix_metadataLongEntries,
                parseSuffix_metadataMaxSize,
                parseSuffix_metadataTooMany,
                parseSuffix_metadataNoPrivate,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseSuffix_urlMechanisms(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("INTERNAL", buffer: &buffer, tracker: tracker)
            let array = try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> MechanismBase64 in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMechanismBase64(buffer: &buffer, tracker: tracker)
            })
            return .urlMechanisms(array)
        }

        func parseSuffix_namespace(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceSuffix(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
                let string = try ParserLibrary.parseBufferAsUTF8(parsed)
                return string
            }
            return .other(atom, string)
        }
        
        let commandParsers: [String: (inout ParseBuffer, StackTracker) throws -> ResponseTextCode] = [
            "ALERT": { _, _ in .alert },
            "ALREADYEXISTS": { _, _ in .alreadyExists },
            "APPENDUID": parseSuffix_appendUID,
            "AUTHENTICATIONFAILED": { _, _ in .authenticationFailed },
            "AUTHORIZATIONFAILED": { _, _ in .authorizationFailed },
            "BADCHARSET": parseSuffix_badCharset,
            "CANNOT": { _, _ in .cannot },
            "CAPABILITY": parseSuffix_capability,
            "CLIENTBUG": { _, _ in .clientBug },
            "CLOSED": { _, _ in .closed },
            "COMPRESSIONACTIVE": { _, _ in .compressionActive },
            "CONTACTADMIN": { _, _ in .contactAdmin },
            "COPYUID": parseSuffix_uidCopy,
            "CORRUPTION": { _, _ in .corruption },
            "EXPIRED": { _, _ in .expired },
            "EXPUNGEISSUED": { _, _ in .expungeIssued },
            "HIGHESTMODSEQ": parseSuffix_highestModifiedSequence,
            "INUSE": { _, _ in .inUse },
            "LIMIT": { _, _ in .limit },
            "METADATA": parseSuffix_metadata,
            "MODIFIED": parseSuffix_modified,
            "NAMESPACE": parseSuffix_namespace,
            "NOMODSEQ": { _, _ in .noModificationSequence },
            "NONEXISTENT": { _, _ in .nonExistent },
            "NOPERM": { _, _ in .noPermission },
            "NOTSAVED": { _, _ in .notSaved },
            "OVERQUOTA": { _, _ in .overQuota },
            "PARSE": { _, _ in .parse },
            "PERMANENTFLAGS": parseSuffix_permanentFlags,
            "PRIVACYREQUIRED": { _, _ in .privacyRequired },
            "READ-ONLY": { _, _ in .readOnly },
            "READ-WRITE": { _, _ in .readWrite },
            "REFERRAL": parseSuffix_referral,
            "SERVERBUG": { _, _ in .serverBug },
            "TRYCREATE": { _, _ in .tryCreate },
            "UIDNEXT": parseSuffix_uidNext,
            "UIDNOTSTICKY": { _, _ in .uidNotSticky },
            "UIDVALIDITY": parseSuffix_uidValidity,
            "UNAVAILABLE": { _, _ in .unavailable },
            "UNSEEN": parseSuffix_unseen,
            "URLMECH": parseSuffix_urlMechanisms,
            "USEATTR": { _, _ in .useAttribute },
        ]

        func parseKnownResponseTextCode(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try parseFromLookupTable(buffer: &buffer, tracker: tracker, parsers: commandParsers)
        }

        return try PL.parseOneOf([
            parseKnownResponseTextCode,
            parseResponseTextCode_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // quota_response  ::= "QUOTA" SP astring SP quota_list
    func parseResponsePayload_quota(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload {
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
    func parseResponsePayload_quotaRoot(buffer: inout ParseBuffer,
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
