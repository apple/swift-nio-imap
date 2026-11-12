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
    // response-data   = "*" SP response-payload CRLF
    func parseResponseData(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed("* ")
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            return payload
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    func parseTaggedResponse(buffer: inout ParseInput, tracker: StackTracker) throws -> TaggedResponse {
        try buffer.composite(tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let state = try self.parseTaggedResponseState(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    func parseSuffix_appendUID(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ResponseTextCode in
            try buffer.parseSpaces()
            let number = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let uids = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
            return .uidAppend(ResponseCodeAppend(uidValidity: number, uids: uids))
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    func parseSuffix_uidCopy(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ResponseTextCode in
            try buffer.parseSpaces()
            let uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let sourceUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let destinationUIDRanges = try self.parseUIDRangeArray(buffer: &buffer, tracker: tracker)
            return .uidCopy(
                ResponseCodeCopy(
                    destinationUIDValidity: uidValidity,
                    sourceUIDs: sourceUIDRanges,
                    destinationUIDs: destinationUIDRanges
                )
            )
        }
    }

    /// A combination of `resp-cond-state`, `resp-cond-bye`, and `greeting`.
    func parseUntaggedResponseStatus(buffer: inout ParseInput, tracker: StackTracker) throws -> UntaggedStatus {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let code = try self.parseAtom(buffer: &buffer, tracker: tracker)

            let parsedSpace: Bool
            do {
                try buffer.parseSpaces()
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
    func parseTaggedResponseState(buffer: inout ParseInput, tracker: StackTracker) throws -> TaggedResponse.State {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let code = try self.parseAtom(buffer: &buffer, tracker: tracker)

            let parsedSpace: Bool
            do {
                try buffer.parseSpaces()
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
    func parseResponsePayload(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload {
        func parseResponsePayload_conditionalState(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponsePayload {
            .conditionalState(try self.parseUntaggedResponseStatus(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_mailboxData(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponsePayload {
            .mailboxData(try self.parseMailboxData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_messageData(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponsePayload {
            .messageData(try self.parseMessageData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_capabilityData(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponsePayload {
            .capabilityData(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_idResponse(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload
        {
            .id(try self.parseIDResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_enableData(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload
        {
            .enableData(try self.parseEnableData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_metadata(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload {
            .metadata(try self.parseMetadataResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_jmapAccess(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload
        {
            .jmapAccess(try self.parseJMAPAccess(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseResponsePayload_mailboxData(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_messageData(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_capabilityData(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_idResponse(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_enableData(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_quota(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_quotaRoot(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_metadata(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_conditionalState(buffer: &$0, tracker: $1) },
                { try parseResponsePayload_jmapAccess(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // resp-text       = ["[" resp-text-code "]" SP] text
    func parseResponseText(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseText {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ResponseText in
            let code = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> ResponseTextCode in
                try buffer.matchFixed("[")
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed("]")
                return code
            }

            // because some servers might not send the text (looking at you, iCloud), they might
            // also not send a space after resp-text-code, so make parsing optional
            try buffer.parseOptional(tracker: tracker, parser: { input, _ in try input.parseSpaces() })

            // text requires minimum 1 char, but we want to be lenient here
            // and allow 0 characters to represent empty text
            let parsed = try buffer.parseZeroOrMoreCharacters { (char) -> Bool in
                char.isUTF8TextByte
            }

            let text = try decodeUTF8(parsed)
            return ResponseText(code: code, text: text)
        }
    }

    /// See https://www.iana.org/assignments/imap-response-codes/imap-response-codes.xhtml
    func parseResponseTextCode(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
        func parseSuffix_modified(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .modified(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_highestModifiedSequence(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .highestModificationSequence(
                try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            )
        }

        func parseSuffix_referral(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .referral(try self.parseIMAPURL(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_badCharset(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            let charsets =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> [CharacterSetName] in
                    try buffer.matchFixed(" (")
                    var array = [try self.parseCharset(buffer: &buffer, tracker: tracker)]
                    try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                        (buffer, tracker) -> CharacterSetName in
                        try buffer.parseSpaces()
                        return try self.parseCharset(buffer: &buffer, tracker: tracker)
                    }
                    try buffer.matchFixed(")")
                    return array
                } ?? []
            return .badCharset(charsets)
        }

        func parseSuffix_capability(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilitySuffix(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_permanentFlags(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            let array = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> [PermanentFlag] in
                var array = [try self.parseFlagPerm(buffer: &buffer, tracker: tracker)]
                try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) in
                    try buffer.parseSpaces()
                    return try self.parseFlagPerm(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try buffer.matchFixed(")")
            return .permanentFlags(array ?? [])
        }

        func parseSuffix_uidNext(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .uidNext(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_uidValidity(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .uidValidity(try self.parseUIDValidity(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_unseen(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .unseen(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_metadata(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            func parseSuffix_metadataLongEntries(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> ResponseTextCode {
                try buffer.matchFixed("LONGENTRIES ")
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                return .metadataLongEntries(num)
            }

            func parseSuffix_metadataMaxSize(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> ResponseTextCode {
                try buffer.matchFixed("MAXSIZE ")
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                return .metadataMaxsize(num)
            }

            func parseSuffix_metadataTooMany(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> ResponseTextCode {
                try buffer.matchFixed("TOOMANY")
                return .metadataTooMany
            }

            func parseSuffix_metadataNoPrivate(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> ResponseTextCode {
                try buffer.matchFixed("NOPRIVATE")
                return .metadataNoPrivate
            }

            try buffer.parseSpaces()

            return try buffer.parseOneOf(
                [
                    { try parseSuffix_metadataLongEntries(buffer: &$0, tracker: $1) },
                    { try parseSuffix_metadataMaxSize(buffer: &$0, tracker: $1) },
                    { try parseSuffix_metadataTooMany(buffer: &$0, tracker: $1) },
                    { try parseSuffix_metadataNoPrivate(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        func parseSuffix_urlMechanisms(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            try buffer.matchFixed("INTERNAL")
            let array = try buffer.parseZeroOrMore(
                tracker: tracker,
                parser: { buffer, tracker -> MechanismBase64 in
                    try buffer.parseSpaces()
                    return try self.parseMechanismBase64(buffer: &buffer, tracker: tracker)
                }
            )
            return .urlMechanisms(array)
        }

        func parseSuffix_namespace(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseSuffix_mailboxID(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            let mailboxID = try parseMailboxIDLeniently(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .mailboxID(.init(mailboxID))
        }

        func parseSuffix_objectID(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            try buffer.parseSpaces()
            return .objectID(try parseCompoundObjectID(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> String in
                try buffer.parseSpaces()
                let parsed = try buffer.parseOneOrMoreCharacters { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
                let string = try decodeUTF8(parsed)
                return string
            }
            return .other(atom, string)
        }

        func parseKnownResponseTextCode(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> ResponseTextCode {
            try self.selectingKeyword(buffer: &buffer) { keyword, buffer in
                switch keyword {
                case "ALERT": return .alert
                case "ALREADYEXISTS": return .alreadyExists
                case "APPENDUID": return try parseSuffix_appendUID(buffer: &buffer, tracker: tracker)
                case "AUTHENTICATIONFAILED": return .authenticationFailed
                case "AUTHORIZATIONFAILED": return .authorizationFailed
                case "BADCHARSET": return try parseSuffix_badCharset(buffer: &buffer, tracker: tracker)
                case "CANNOT": return .cannot
                case "CAPABILITY": return try parseSuffix_capability(buffer: &buffer, tracker: tracker)
                case "CLIENTBUG": return .clientBug
                case "CLOSED": return .closed
                case "COMPRESSIONACTIVE": return .compressionActive
                case "CONTACTADMIN": return .contactAdmin
                case "COPYUID": return try parseSuffix_uidCopy(buffer: &buffer, tracker: tracker)
                case "CORRUPTION": return .corruption
                case "EXPIRED": return .expired
                case "EXPUNGEISSUED": return .expungeIssued
                case "HIGHESTMODSEQ": return try parseSuffix_highestModifiedSequence(buffer: &buffer, tracker: tracker)
                case "INUSE": return .inUse
                case "LIMIT": return .limit
                case "MAILBOXID": return try parseSuffix_mailboxID(buffer: &buffer, tracker: tracker)
                case "METADATA": return try parseSuffix_metadata(buffer: &buffer, tracker: tracker)
                case "MODIFIED": return try parseSuffix_modified(buffer: &buffer, tracker: tracker)
                case "NAMESPACE": return try parseSuffix_namespace(buffer: &buffer, tracker: tracker)
                case "NOMODSEQ": return .noModificationSequence
                case "NONEXISTENT": return .nonExistent
                case "NOPERM": return .noPermission
                case "NOTSAVED": return .notSaved
                case "OBJECTID": return try parseSuffix_objectID(buffer: &buffer, tracker: tracker)
                case "OVERQUOTA": return .overQuota
                case "PARSE": return .parse
                case "PERMANENTFLAGS": return try parseSuffix_permanentFlags(buffer: &buffer, tracker: tracker)
                case "PRIVACYREQUIRED": return .privacyRequired
                case "READ-ONLY": return .readOnly
                case "READ-WRITE": return .readWrite
                case "REFERRAL": return try parseSuffix_referral(buffer: &buffer, tracker: tracker)
                case "SERVERBUG": return .serverBug
                case "TRYCREATE": return .tryCreate
                case "UIDNEXT": return try parseSuffix_uidNext(buffer: &buffer, tracker: tracker)
                case "UIDNOTSTICKY": return .uidNotSticky
                case "UIDREQUIRED": return .uidRequired
                case "UIDVALIDITY": return try parseSuffix_uidValidity(buffer: &buffer, tracker: tracker)
                case "UNAVAILABLE": return .unavailable
                case "UNSEEN": return try parseSuffix_unseen(buffer: &buffer, tracker: tracker)
                case "URLMECH": return try parseSuffix_urlMechanisms(buffer: &buffer, tracker: tracker)
                case "USEATTR": return .useAttribute
                default: throw ParserError(hint: "Not a response-text-code keyword")
                }
            }
        }

        return try buffer.parseOneOf(
            [
                { try parseKnownResponseTextCode(buffer: &$0, tracker: $1) },
                { try parseResponseTextCode_atom(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // quota_response  ::= "QUOTA" SP astring SP quota_list
    func parseResponsePayload_quota(buffer: inout ParseInput, tracker: StackTracker) throws -> ResponsePayload {
        // quota_resource  ::= atom SP number SP number
        func parseQuotaResource(buffer: inout ParseInput, tracker: StackTracker) throws -> QuotaResource {
            try buffer.composite(tracker: tracker) { buffer, tracker in
                let resourceName = try parseQuotaResourceName(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let usage = try parseNumber(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaResource(resourceName: resourceName, usage: usage, limit: limit)
            }
        }

        // quota_list      ::= "(" #quota_resource ")"
        func parseQuotaList(buffer: inout ParseInput, tracker: StackTracker) throws -> [QuotaResource] {
            try buffer.composite(tracker: tracker) { buffer, tracker in
                try buffer.matchFixed("(")
                var resources: [QuotaResource] = []
                while true {
                    let mark = buffer.consumed
                    guard
                        let resource = try buffer.parseOptional(
                            tracker: tracker,
                            parser: { try parseQuotaResource(buffer: &$0, tracker: $1) }
                        )
                    else { break }
                    try buffer.requireProgress(since: mark)
                    resources.append(resource)
                    let space: Void? = try buffer.parseOptional(tracker: tracker) { input, _ in
                        try input.parseSpaces()
                    }
                    if space == nil {
                        break
                    }
                }
                try buffer.matchFixed(")")
                return resources
            }
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("QUOTA ")
            let quotaRoot = try parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let resources = try parseQuotaList(buffer: &buffer, tracker: tracker)
            return .quota(.init(quotaRoot), resources)
        }
    }

    // quotaroot_response ::= "QUOTAROOT" SP astring *(SP astring)
    func parseResponsePayload_quotaRoot(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> ResponsePayload {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("QUOTAROOT ")
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            let quotaRoots = try buffer.parseZeroOrMore(tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
                return try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            }
            return .quotaRoot(mailbox, quotaRoots)
        }
    }
}
