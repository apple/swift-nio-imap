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

struct _IncompleteMessage: Error {
    init() {}
}

enum GrammarParser {}

// MARK: - Grammar Parsers

extension GrammarParser {
    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try oneOf([
            Self.parseString,
            parseOneOrMoreASTRINGCHAR,
        ], buffer: &buffer, tracker: tracker)
    }

    // atom            = 1*ATOM-CHAR
    static func parseAtom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar
        }
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    static func parseAttributeFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
        func parseAttributeFlag_slashed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
            try fixedString("\\\\", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(atom)
        }

        return try oneOf([
            parseAttributeFlag_slashed,
            parseAttributeFlag_unslashed,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAuthIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURL {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURL in
            try fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let messagePart = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePart: messagePart)
        }
    }

    static func parseAuthIMAPURLFull(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURLFull {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURLFull in
            let imapURL = try self.parseAuthIMAPURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(imapURL: imapURL, urlAuth: urlAuth)
        }
    }

    static func parseAuthIMAPURLRump(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURLRump {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURLRump in
            let imapURL = try self.parseAuthIMAPURL(buffer: &buffer, tracker: tracker)
            let authRump = try self.parseIURLAuthRump(buffer: &buffer, tracker: tracker)
            return .init(imapURL: imapURL, authRump: authRump)
        }
    }

    // authenticate  = "AUTHENTICATE" SP auth-type [SP (base64 / "=")] *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("AUTHENTICATE ", buffer: &buffer, tracker: tracker)
            let authMethod = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let parseInitialClientResponse = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> InitialClientResponse in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseInitialClientResponse(buffer: &buffer, tracker: tracker)
            })
            return .authenticate(method: authMethod, initialClientResponse: parseInitialClientResponse)
        }
    }

    static func parseInitialClientResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
        func parseInitialClientResponse_empty(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            try fixedString("=", buffer: &buffer, tracker: tracker)
            return .empty
        }

        func parseInitialClientResponse_data(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .init(data: base64)
        }

        return try oneOf([
            parseInitialClientResponse_empty,
            parseInitialClientResponse_data,
        ], buffer: &buffer, tracker: tracker)
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq ..< readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }

            do {
                let decoded = try Base64.decode(encoded: String(buffer: bytes))
                return ByteBuffer(ByteBufferView(decoded))
            } catch {
                throw ParserError(hint: "Invalid base64 \(error)")
            }
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    static func parseCapability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    static func parseCapabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try fixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // charset          = atom / quoted
    static func parseCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        func parseCharset_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseCharset_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            return string
        }

        return try oneOf([
            parseCharset_atom,
            parseCharset_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseChangedSinceModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChangedSinceModifier {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ChangedSinceModifier in
            try fixedString("CHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    static func parseUnchangedSinceModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UnchangedSinceModifier {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> UnchangedSinceModifier in
            try fixedString("UNCHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try fixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinuationRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinuationRequest {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinuationRequest in
            try fixedString("+", buffer: &buffer, tracker: tracker)
            // Allow no space and no additional text after "+":
            let req: ContinuationRequest
            if try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                if let base64 = try? self.parseBase64(buffer: &buffer, tracker: tracker), base64.readableBytes > 0 {
                    req = .data(base64)
                } else {
                    req = .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
                }
            } else {
                req = .responseText(ResponseText(code: nil, text: ""))
            }
            try newline(buffer: &buffer, tracker: tracker)
            return req
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("COPY ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("CREATE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // create-param = create-param-name [SP create-param-value]

    static func parseCreateParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseCreateParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
        func parseCreateParameter_parameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
            try fixedString("USE (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        return try oneOf([
            parseCreateParameter_specialUse,
            parseCreateParameter_parameter,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue?> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: value)
        }
    }

    static func parseUseAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
        func parseUseAttribute_fixed(expected: String, returning: UseAttribute, buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try fixedString(expected, buffer: &buffer, tracker: tracker)
            return returning
        }

        func parseUseAttribute_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\All", returning: .all, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_archive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Archive", returning: .archive, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_drafts(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Drafts", returning: .drafts, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Flagged", returning: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_junk(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Junk", returning: .junk, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_sent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Sent", returning: .sent, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_trash(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Trash", returning: .trash, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\" + att)
        }

        return try oneOf([
            parseUseAttribute_all,
            parseUseAttribute_archive,
            parseUseAttribute_drafts,
            parseUseAttribute_flagged,
            parseUseAttribute_junk,
            parseUseAttribute_sent,
            parseUseAttribute_trash,
            parseUseAttribute_other,
        ], buffer: &buffer, tracker: tracker)
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("DELETE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("ENABLE", buffer: &buffer, tracker: tracker)
            let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
            return .enable(capabilities)
        }
    }

    static func parseEncodedAuthenticationType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedAuthenticationType {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedAuthenticationType in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(authType: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedMailbox {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedMailbox in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(mailbox: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedSearch {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSearch in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(query: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedSection {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSection in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(section: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedUser(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedUser {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedUser in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(data: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedURLAuth {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ -> EncodedURLAuth in
            guard let bytes = buffer.readSlice(length: 32) else {
                throw _IncompleteMessage()
            }
            guard bytes.readableBytesView.allSatisfy({ $0.isHexCharacter }) else {
                throw ParserError(hint: "Found invalid character in \(String(buffer: bytes))")
            }
            return .init(data: String(buffer: bytes))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try fixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)
    static func parseEsearchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchResponse {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ESearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("EXAMINE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .examine(mailbox, params)
        }
    }

    static func parseExpire(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Expire {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Expire in
            try fixedString(";EXPIRE=", buffer: &buffer, tracker: tracker)
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    static func parseAccess(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
        func parseAccess_submit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("submit+", buffer: &buffer, tracker: tracker)
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("user+", buffer: &buffer, tracker: tracker)
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authuser(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("authuser", buffer: &buffer, tracker: tracker)
            return .authUser
        }

        func parseAccess_anonymous(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("anonymous", buffer: &buffer, tracker: tracker)
            return .anonymous
        }

        return try oneOf([
            parseAccess_submit,
            parseAccess_user,
            parseAccess_authuser,
            parseAccess_anonymous,
        ], buffer: &buffer, tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    static func parseFilterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    static func parseFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
        func parseFlag_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Draft", buffer: &buffer, tracker: tracker)
            return .draft
        }

        func parseFlag_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        return try oneOf([
            parseFlag_seen,
            parseFlag_draft,
            parseFlag_answered,
            parseFlag_flagged,
            parseFlag_deleted,
            parseFlag_keyword,
            parseFlag_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-extension  = "\" atom
    static func parseFlagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try optional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try fixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    static func parseFlagPerm(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try fixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFlagPerm_wildcard,
            parseFlagPerm_flag,
        ], buffer: &buffer, tracker: tracker)
    }

    // header-fld-name = astring
    static func parseHeaderFieldName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    static func parseHeaderList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    static func parseICommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
        func parseICommand_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
            .messageList(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseICommand_part(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
            let part = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            let auth = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIURLAuth)
            return .messagePart(part: part, urlAuth: auth)
        }

        return try oneOf([
            parseICommand_part,
            parseICommand_list,
        ], buffer: &buffer, tracker: tracker)
    }

    // id = "ID" SP id-params-list
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    static func parseINetworkPath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> INetworkPath {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> INetworkPath in
            try fixedString("//", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseIAbsolutePath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAbsolutePath {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> IAbsolutePath in
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseIAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
        func parseIAuth_any(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
            try fixedString("*", buffer: &buffer, tracker: tracker)
            return .any
        }

        func parseIAuth_encoded(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(";AUTH=", buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseIAuth_any,
                parseIAuth_encoded,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    static func parseIDParamsList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
        func parseIDParamsList_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> (String, ByteBuffer?) {
            let key = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return (key, value)
        }

        func parseIDParamsList_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let (key, value) = try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            var dic: KeyValues<String, ByteBuffer?> = [key: value]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &dic, tracker: tracker) { (buffer, tracker) -> (String, ByteBuffer?) in
                try space(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return dic
        }

        return try oneOf([
            parseIDParamsList_nil,
            parseIDParamsList_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // idle            = "IDLE" CRLF "DONE"
    static func parseIdleStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try fixedString("IDLE", buffer: &buffer, tracker: tracker)
        return .idleStart
    }

    static func parseIdleDone(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("DONE", buffer: &buffer, tracker: tracker)
        try newline(buffer: &buffer, tracker: tracker)
    }

    static func parseIPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPartial {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try fixedString("/;PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIPartialOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPartial {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try fixedString(";PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIPathQuery(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPathQuery {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPathQuery in
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseISection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ISection {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISection in
            try fixedString("/;SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseISectionOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ISection {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISection in
            try fixedString(";SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIServer(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IServer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IServer in
            let info = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IUserInfo in
                let info = try self.parseIUserInfo(buffer: &buffer, tracker: tracker)
                try fixedString("@", buffer: &buffer, tracker: tracker)
                return info
            })
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try fixedString(":", buffer: &buffer, tracker: tracker)
                return try self.parseNumber(buffer: &buffer, tracker: tracker)
            })
            return .init(userInfo: info, host: host, port: port)
        }
    }

    static func parseHost(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_ipv6(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_future(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseHost_literal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let address = try oneOf([
                parseHost_ipv6,
                parseHost_future,
            ], buffer: &buffer, tracker: tracker)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return address
        }

        func parseHost_regularName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            var newBuffer = ByteBuffer()
            while true {
                do {
                    let chars = try self.parseUChar(buffer: &buffer, tracker: tracker)
                    newBuffer.writeBytes(chars)
                } catch is ParserError {
                    break
                }
            }
            return String(buffer: newBuffer)
        }

        // TODO: This isn't great, but it is functional. Perhaps make it actually enforce IPv4 rules
        func parseHost_ipv4(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num3 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num4 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return "\(num1).\(num2).\(num3).\(num4)"
        }

        return try oneOf([
            parseHost_literal,
            parseHost_regularName,
            parseHost_ipv4,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMailboxReference(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMailboxReference {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMailboxReference in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UIDValidity in
                try fixedString(";UIDVALIDITY=", buffer: &buffer, tracker: tracker)
                return try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            })
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    static func parseIMessageList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageList {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessageList in
            let mailboxRef = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let query = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> EncodedSearch in
                try fixedString("?", buffer: &buffer, tracker: tracker)
                return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
            })
            return .init(mailboxReference: mailboxRef, encodedSearch: query)
        }
    }

    static func parseIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMAPURL {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPURL in
            try fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseRelativeIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
        func parseRelativeIMAPURL_absolute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .absolutePath(try self.parseIAbsolutePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_network(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .networkPath(try self.parseINetworkPath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_relative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .relativePath(try self.parseIRelativePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_empty(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .empty
        }

        return try oneOf([
            parseRelativeIMAPURL_network,
            parseRelativeIMAPURL_absolute,
            parseRelativeIMAPURL_relative,
            parseRelativeIMAPURL_empty,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIRelativePath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
        func parseIRelativePath_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
            .list(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseIRelativePath_messageOrPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
            .messageOrPartial(try self.parseIMessageOrPartial(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseIRelativePath_list,
            parseIRelativePath_messageOrPartial,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMessagePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessagePart {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessagePart in
            var ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)

            var uid = try IUID(uid: 1)
            if ref.uidValidity == nil, ref.encodedMailbox.mailbox.last == Character(.init(UInt8(ascii: "/"))) {
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    ref.encodedMailbox.mailbox = String(ref.encodedMailbox.mailbox.dropLast())
                    var newBuffer = ByteBuffer(ByteBufferView([UInt8(ascii: "/")]))
                    newBuffer.writeBuffer(&buffer)
                    uid = try self.parseIUID(buffer: &newBuffer, tracker: tracker)
                    buffer = newBuffer
                }
            } else {
                uid = try self.parseIUID(buffer: &buffer, tracker: tracker)
            }

            var section = try optional(buffer: &buffer, tracker: tracker, parser: self.parseISection)
            var partial: IPartial?
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                    var newBuffer = ByteBuffer(ByteBufferView([UInt8(ascii: "/")]))
                    newBuffer.writeBuffer(&buffer)
                    partial = try optional(buffer: &newBuffer, tracker: tracker, parser: self.parseIPartial)
                    buffer = newBuffer
                }
            } else {
                partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartial)
            }
            return .init(mailboxReference: ref, iUID: uid, iSection: section, iPartial: partial)
        }
    }

    static func parseIMessageOrPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
        func parseIMessageOrPartial_partialOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let partial = try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseIMessageOrPartial_sectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            var section = try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            if section.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section.encodedSection.section = String(section.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .sectionPartial(section: section, partial: partial)
                } catch is ParserError {
                    section.encodedSection.section.append("/")
                    return .sectionPartial(section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .sectionPartial(section: section, partial: partial)
        }

        func parseIMessageOrPartial_uidSectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISection in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .uidSectionPartial(uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .uidSectionPartial(uid: uid, section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseIMessageOrPartial_refUidSectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISection in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        return try oneOf([
            parseIMessageOrPartial_refUidSectionPartial,
            parseIMessageOrPartial_uidSectionPartial,
            parseIMessageOrPartial_sectionPartial,
            parseIMessageOrPartial_partialOnly,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseUChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let num = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            guard num.isUnreserved else {
                throw ParserError(hint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let num = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            guard num.isSubDelimsSh else {
                throw ParserError(hint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            try fixedString("%", buffer: &buffer, tracker: tracker)
            guard
                var h1 = buffer.readInteger(as: UInt8.self),
                var h2 = buffer.readInteger(as: UInt8.self)
            else {
                throw _IncompleteMessage()
            }

            guard h1.isHexCharacter, h2.isHexCharacter else {
                throw ParserError(hint: "Expected 2 hex digits, got \(h1) and \(h2)")
            }

            if h1 > UInt8(ascii: "F") {
                h1 -= 32
            }
            if h2 > UInt8(ascii: "F") {
                h2 -= 32
            }

            return [UInt8(ascii: "%"), h1, h2]
        }

        return try oneOf([
            parseUChar_unreserved,
            parseUChar_subDelimsSH,
            parseUChar_pctEncoded,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseAChar_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let char = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw ParserError(hint: "Expect achar, got \(char)")
            }
        }

        return try oneOf([
            parseUChar,
            parseAChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseBChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseBChar_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let char = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw ParserError(hint: "Expect bchar, got \(char)")
            }
        }

        return try oneOf([
            parseAChar,
            parseBChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIUID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUID {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("/;UID=", buffer: &buffer, tracker: tracker)
            return try IUID(uid: try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIUIDOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUID {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString(";UID=", buffer: &buffer, tracker: tracker)
            return try IUID(uid: try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IURLAuth {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IURLAuth in
            let rump = try self.parseIURLAuthRump(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseIUAVerifier(buffer: &buffer, tracker: tracker)
            return .init(auth: rump, verifier: verifier)
        }
    }

    static func parseURLRumpMechanism(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RumpURLAndMechanism {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> RumpURLAndMechanism in
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    static func parseURLFetchData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> URLFetchData {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLFetchData in
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let data = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(url: url, data: data)
        }
    }

    static func parseIURLAuthRump(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IURLAuthRump {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IURLAuthRump in
            let expiry = try optional(buffer: &buffer, tracker: tracker, parser: self.parseExpire)
            try fixedString(";URLAUTH=", buffer: &buffer, tracker: tracker)
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    static func parseIUAVerifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUAVerifier {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IUAVerifier in
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(uAuthMechanism: authMechanism, encodedURLAuth: urlAuth)
        }
    }

    static func parseIUserInfo(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUserInfo {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IUserInfo in
            let encodedUser = try optional(buffer: &buffer, tracker: tracker, parser: self.parseEncodedUser)
            let iauth = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIAuth)
            guard (encodedUser != nil || iauth != nil) else {
                throw ParserError(hint: "Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, iAuth: iauth)
        }
    }

    static func parseFullDateTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullDateTime {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try fixedString("T", buffer: &buffer, tracker: tracker)
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    static func parseFullDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullDate {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    static func parseFullTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try fixedString(":", buffer: &buffer, tracker: tracker)
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try fixedString(":", buffer: &buffer, tracker: tracker)
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
            try fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        })
        return .init(hour: hour, minute: minute, second: second, fraction: fraction)
    }

    static func parseLiteralSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("~", buffer: &buffer, tracker: tracker)
            }
            try fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw _IncompleteMessage()
            }
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral8(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("~{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw _IncompleteMessage()
            }
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("LOGIN ", buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try fixedString("LSUB ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Kind_defined(_ option: String, result: Media.BasicKind, buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            try fixedString(option, buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Kind_application(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_audio(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_image(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_video(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(String(buffer: buffer))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try oneOf([
                parseMediaBasic_Kind_application,
                parseMediaBasic_Kind_audio,
                parseMediaBasic_Kind_image,
                parseMediaBasic_Kind_message,
                parseMediaBasic_Kind_video,
                parseMediaBasic_Kind_other,
            ], buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(kind: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try fixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try fixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try oneOf([
                parseMediaMessage_rfc,
            ], buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.MediaSubtype {
        let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        let string = String(buffer: buffer)
        return .init(string)
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try fixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseString(buffer: &buffer, tracker: tracker)
            return String(buffer: subtype)
        }
    }

    static func parseMetadataOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
        func parseMetadataOption_maxSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            try fixedString("MAXSIZE ", buffer: &buffer, tracker: tracker)
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMetadataOption_maxSize,
            parseMetadataOption_scope,
            parseMetadataOption_param,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MetadataOption] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseMetadataResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
        func parseMetadataResponse_values(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try oneOf([
            parseMetadataResponse_values,
            parseMetadataResponse_list,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
        func parseMetadataValue_nstring(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataValue_literal8(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseLiteral8(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMetadataValue_nstring,
            parseMetadataValue_literal8,
        ], buffer: &buffer, tracker: tracker)
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("MOVE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    static func parseMechanismBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MechanismBase64 {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MechanismBase64 in
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
                try fixedString("=", buffer: &buffer, tracker: tracker)
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    static func parseGmailLabel(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
        func parseGmailLabel_backslash(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(ByteBuffer(ByteBufferView("\\\(att)".utf8)))
        }

        func parseGmailLabel_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(raw)
        }

        return try oneOf([
            parseGmailLabel_backslash,
            parseGmailLabel_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try oneOf([
            parseNamespace_nil,
            parseNamespace_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Command = "NAMESPACE"
    static func parseNamespaceCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try fixedString("NAMESPACE", buffer: &buffer, tracker: tracker)
        return .namespace
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            guard let char = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let char = try oneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(string: string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    static func parseNamespaceResponseExtensions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceResponseExtension] {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NamespaceResponseExtension in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    static func parseNamespaceResponseExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponseExtension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponseExtension in
            try space(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return NamespaceResponseExtension(string: s1, array: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try fixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try fixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try oneOf([
            parseNString_nil,
            parseNString_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // number          = 1*DIGIT
    static func parseNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    static func parseNZNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        if case .some(UInt8(ascii: "0")) = buffer.readableBytesView.first {
            throw ParserError(hint: "Number began with 0 ")
        }
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    static func parseOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<OptionExtensionKind, OptionValueComp?> {
        func parseOptionExtensionKind_standard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .standard(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionKind_vendor(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<OptionExtensionKind, OptionValueComp?> in
            let type = try oneOf([
                parseOptionExtensionKind_standard,
                parseOptionExtensionKind_vendor,
            ], buffer: &buffer, tracker: tracker)
            let value = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try oneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionVendorTag {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return OptionVendorTag(token: token, atom: atom)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ClosedRange<UInt32> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
            try fixedString("<", buffer: &buffer, tracker: tracker)
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try fixedString(".", buffer: &buffer, tracker: tracker)
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try fixedString(">", buffer: &buffer, tracker: tracker)
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return num1 ... upper2.partialValue
        }
    }

    static func parsePartialRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PartialRange {
        func parsePartialRange_length(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
            try fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> PartialRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try optional(buffer: &buffer, tracker: tracker, parser: parsePartialRange_length)
            return .init(offset: offset, length: length)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("RENAME ", buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .rename(from: from, to: to, params: params)
        }
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try fixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseScopeOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
        func parseScopeOption_zero(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("0", buffer: &buffer, tracker: tracker)
            return .zero
        }

        func parseScopeOption_one(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("1", buffer: &buffer, tracker: tracker)
            return .one
        }

        func parseScopeOption_infinity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("infinity", buffer: &buffer, tracker: tracker)
            return .infinity
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("DEPTH ", buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseScopeOption_zero,
                parseScopeOption_one,
                parseScopeOption_infinity,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSection_none(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier in
                try fixedString("[]", buffer: &buffer, tracker: tracker)
                return .complete
            }
        }

        func parseSection_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }

        return try oneOf([
            parseSection_none,
            parseSection_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let part = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSectionPart)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return part ?? .init([])
        }
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try fixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpecifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            return .init(kind: kind)
        }

        func parseSectionSpecifier_withPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                try fixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try oneOf([
            parseSectionSpecifier_withPart,
            parseSectionSpecifier_noPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionSpecifierKind(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("MIME", buffer: &buffer, tracker: tracker)
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionSpecifierKind_headerFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        func parseSectionSpecifierKind_complete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try oneOf([
            parseSectionSpecifierKind_mime,
            parseSectionSpecifierKind_headerFields,
            parseSectionSpecifierKind_notHeaderFields,
            parseSectionSpecifierKind_header,
            parseSectionSpecifierKind_text,
            parseSectionSpecifierKind_complete,
        ], buffer: &buffer, tracker: tracker)
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("SELECT ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SelectParameter] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            }
            return .select(mailbox, params ?? [])
        }
    }

    static func parseSelectParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
        func parseSelectParameter_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            try fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
            return .condstore
        }

        func parseSelectParameter_qresync(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            try fixedString("QRESYNC (", buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUids = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceSet in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseKnownUids(buffer: &buffer, tracker: tracker)
            })
            let seqMatchData = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceMatchData in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSequenceMatchData(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .qresync(.init(uidValiditiy: uidValidity, modificationSequenceValue: modSeqVal, knownUids: knownUids, sequenceMatchData: seqMatchData))
        }

        return try oneOf([
            parseSelectParameter_qresync,
            parseSelectParameter_condstore,
            parseSelectParameter_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseKnownUids(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
        try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [KeyValue<String, ParameterValue?>] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [KeyValue<String, ParameterValue?>] in
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> KeyValue<String, ParameterValue?> in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseSortData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SortData? {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SortData? in
            try fixedString("SORT", buffer: &buffer, tracker: tracker)
            let _components = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ([Int], ModificationSequenceValue) in
                try space(buffer: &buffer, tracker: tracker)
                var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                })
                try space(buffer: &buffer, tracker: tracker)
                let seq = try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
                return (array, seq)
            }

            guard let components = _components else {
                return nil
            }
            return SortData(identifiers: components.0, modificationSequence: components.1)
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    static func parseStatusAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try fixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("STORE ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> [StoreModifier] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            try space(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    static func parseStoreModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
        func parseFetchModifier_unchangedSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFetchModifier_unchangedSince,
            parseFetchModifier_other,
        ], buffer: &buffer, tracker: tracker)
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreAttributeFlags_silent(buffer: inout ByteBuffer, tracker: StackTracker) -> Bool {
            do {
                try fixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Flag in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_operation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags.Operation {
            try oneOf([
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .replace
                },
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> StoreFlags in
            let operation = try parseStoreAttributeFlags_operation(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let flags = try oneOf([
                parseStoreAttributeFlags_array,
                parseFlagList,
            ], buffer: &buffer, tracker: tracker)
            return StoreFlags(operation: operation, silent: silent, flags: flags)
        }
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try oneOf([
            Self.parseQuoted,
            Self.parseLiteral,
        ], buffer: &buffer, tracker: tracker)
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("SUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    static func parseTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAStringChar && char != UInt8(ascii: "+")
        }
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let key = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if key.lowercased() == "catenate" {
                throw ParserError(hint: "catenate extension")
            }

            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            guard let fchar = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let trailing = try ParserLibrary.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isTaggedLabelChar
            }

            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    static func parseTaggedExtensionComplex_continuation(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        while true {
            do {
                try space(buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                return
            }
        }
    }

    static func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            into.append(String(buffer: try self.parseAString(buffer: &buffer, tracker: tracker)))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try fixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let save = buffer
            do {
                try parseTaggedExtensionComplex_string(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                buffer = save
                try parseTaggedExtensionComplex_bracketed(into: &into, buffer: &buffer, tracker: tracker)
            }
        }
    }

    // NOTE: Left-recursive, modification above, this needs some work
    // tagged-ext-comp     = astring /
    //                       tagged-ext-comp *(SP tagged-ext-comp) /
    //                       "(" tagged-ext-comp ")"
    static func parseTaggedExtensionComplex(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
        func parseTaggedExtensionSimple_set(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try optional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try oneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionVal_comp,
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    static func parseUAuthMechanism(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UAuthMechanism {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker, where: { char in
            switch char {
            case UInt8(ascii: "a") ... UInt8(ascii: "z"),
                 UInt8(ascii: "A") ... UInt8(ascii: "Z"),
                 UInt8(ascii: "0") ... UInt8(ascii: "9"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."):
                return true
            default:
                return false
            }
        })
        return UAuthMechanism(string)
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("UNSUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // userid          = astring
    static func parseUserId(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var astring = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return astring.readString(length: astring.readableBytes)! // if this fails, something has gone very, very wrong
    }

    // vendor-token     = atom (maybe?!?!?!)
    static func parseVendorToken(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAlpha
        }
    }

    // RFC 2087 = "GETQUOTA" / "GETQUOTAROOT" / "SETQUOTA"
    static func parseCommandQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseQuotaRoot(buffer: inout ByteBuffer, tracker: StackTracker) throws -> QuotaRoot {
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return QuotaRoot(string)
        }

        // setquota_list   ::= "(" 0#setquota_resource ")"
        func parseQuotaLimits(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [QuotaLimit] {
            // setquota_resource ::= atom SP number
            func parseQuotaLimit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> QuotaLimit {
                try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                    let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                    try space(buffer: &buffer, tracker: tracker)
                    let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                    return QuotaLimit(resourceName: resourceName, limit: limit)
                }
            }

            return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) throws -> [QuotaLimit] in
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var limits: [QuotaLimit] = []
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    while let limit = try optional(buffer: &buffer, tracker: tracker, parser: parseQuotaLimit) {
                        limits.append(limit)
                        if try optional(buffer: &buffer, tracker: tracker, parser: space) == nil {
                            break
                        }
                    }
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return limits
            }
        }

        // getquota        ::= "GETQUOTA" SP astring
        func parseCommandQuota_getQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("GETQUOTA ", buffer: &buffer, tracker: tracker)
                let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
                return .getQuota(quotaRoot)
            }
        }

        // getquotaroot    ::= "GETQUOTAROOT" SP astring
        func parseCommandQuota_getQuotaRoot(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("GETQUOTAROOT ", buffer: &buffer, tracker: tracker)
                let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
                return .getQuotaRoot(mailbox)
            }
        }

        // setquota        ::= "SETQUOTA" SP astring SP setquota_list
        func parseCommandQuota_setQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("SETQUOTA ", buffer: &buffer, tracker: tracker)
                let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let quotaLimits = try parseQuotaLimits(buffer: &buffer, tracker: tracker)
                return .setQuota(quotaRoot, quotaLimits)
            }
        }

        return try oneOf([
            parseCommandQuota_getQuota,
            parseCommandQuota_getQuotaRoot,
            parseCommandQuota_setQuota,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 5465
    // one-or-more-mailbox = mailbox / many-mailboxes
    static func parseOneOrMoreMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
        // many-mailboxes  = "(" mailbox *(SP mailbox) ")
        func parseManyMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap mailboxes which should be impossible")
            }
        }

        func parseSingleMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
            let mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap single mailboxes which should be impossible")
            }
        }

        return try oneOf([
            parseManyMailboxes,
            parseSingleMailboxes,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    static func parseFilterMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("selected", buffer: &buffer, tracker: tracker)
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("selected-delayed", buffer: &buffer, tracker: tracker)
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("inboxes", buffer: &buffer, tracker: tracker)
            return .inboxes
        }

        func parseFilterMailboxes_Personal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("personal", buffer: &buffer, tracker: tracker)
            return .personal
        }

        func parseFilterMailboxes_Subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subscribed", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subtree ", buffer: &buffer, tracker: tracker)
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("mailboxes ", buffer: &buffer, tracker: tracker)
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 6237
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subtree-one ", buffer: &buffer, tracker: tracker)
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFilterMailboxes_SelectedDelayed,
            parseFilterMailboxes_SubtreeOne,
            parseFilterMailboxes_Selected,
            parseFilterMailboxes_Inboxes,
            parseFilterMailboxes_Personal,
            parseFilterMailboxes_Subscribed,
            parseFilterMailboxes_Subtree,
            parseFilterMailboxes_Mailboxes,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 6237
    // scope-options =  scope-option *(SP scope-option)
    static func parseESearchScopeOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchScopeOptions {
        var options: [KeyValue<String, ParameterValue?>] = [try parseParameter(buffer: &buffer, tracker: tracker)]
        while try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
            options.append(try parseParameter(buffer: &buffer, tracker: tracker))
        }
        if let returnValue = ESearchScopeOptions(options) {
            return returnValue
        } else {
            throw ParserError(hint: "Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
    }

    // RFC 6237
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    static func parseEsearchSourceOptions(buffer: inout ByteBuffer,
                                          tracker: StackTracker) throws -> ESearchSourceOptions {
        func parseEsearchSourceOptions_spaceFilter(buffer: inout ByteBuffer,
                                                   tracker: StackTracker) throws -> MailboxFilter {
            try space(buffer: &buffer, tracker: tracker)
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseEsearchSourceOptions_sourceMBox(buffer: inout ByteBuffer,
                                                  tracker: StackTracker) throws -> [MailboxFilter] {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            while let anotherSource = try optional(buffer: &buffer,
                                                   tracker: tracker,
                                                   parser: parseEsearchSourceOptions_spaceFilter) {
                sources.append(anotherSource)
            }
            return sources
        }

        func parseEsearchSourceOptions_scopeOptions(buffer: inout ByteBuffer,
                                                    tracker: StackTracker) throws -> ESearchScopeOptions {
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            let result = try parseESearchScopeOptions(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("IN (", buffer: &buffer, tracker: tracker)
            let sourceMbox = try parseEsearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try optional(buffer: &buffer,
                                            tracker: tracker,
                                            parser: parseEsearchSourceOptions_scopeOptions)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            if let result = ESearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) {
                return result
            } else {
                throw ParserError(hint: "Failed to construct esearch source options")
            }
        }
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    // Ignoring the command here.
    static func parseEsearchOptions(buffer: inout ByteBuffer,
                                    tracker: StackTracker) throws -> ESearchOptions {
        func parseEsearchOptions_sourceOptions(buffer: inout ByteBuffer,
                                               tracker: StackTracker) throws -> ESearchSourceOptions {
            try space(buffer: &buffer, tracker: tracker)
            let result = try parseEsearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try optional(buffer: &buffer,
                                         tracker: tracker,
                                         parser: parseEsearchOptions_sourceOptions)
        let returnOpts = try optional(buffer: &buffer,
                                      tracker: tracker,
                                      parser: self.parseSearchReturnOptions) ?? []
        try space(buffer: &buffer, tracker: tracker)
        let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
        return ESearchOptions(key: program, charset: charset, returnOptions: returnOpts, sourceOptions: sourceOptions)
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    static func parseEsearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            return .esearch(try parseEsearchOptions(buffer: &buffer, tracker: tracker))
        }
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    static func parse2Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ByteBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
            guard size == bytes else {
                throw ParserError(hint: "Expected \(bytes) digits, got \(size)")
            }
            return num
        }
    }
}

struct StackTracker {
    private var stackDepth = 0
    private let maximumStackDepth: Int

    static var makeNewDefaultLimitStackTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 100)
    }

    init(maximumParserStackDepth: Int) {
        self.maximumStackDepth = maximumParserStackDepth
    }

    mutating func newStackFrame() throws {
        self.stackDepth += 1
        guard self.stackDepth < self.maximumStackDepth else {
            throw TooMuchRecursion(limit: self.maximumStackDepth)
        }
    }
}

// MARK: - Parser Library

extension GrammarParser {
    static func space(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ in

            // need at least one readable byte
            guard buffer.readableBytes > 0 else { throw _IncompleteMessage() }

            // if there are only spaces then just consume it all and move on
            guard let index = buffer.readableBytesView.firstIndex(where: { $0 != UInt8(ascii: " ") }) else {
                buffer.moveReaderIndex(to: buffer.writerIndex)
                return
            }

            // first character wasn't a space
            guard index > buffer.readableBytesView.startIndex else {
                throw ParserError(hint: "Expected space, found \(buffer.readableBytesView[index])")
            }

            buffer.moveReaderIndex(to: index)
        }
    }

    static func fixedString(_ needle: String, caseSensitive: Bool = false, buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let needleCount = needle.utf8.count
            guard let actual = buffer.readString(length: needleCount) else {
                guard needle.utf8.starts(with: buffer.readableBytesView, by: { $0 & 0xDF == $1 & 0xDF }) else {
                    throw ParserError(hint: "Tried to parse \(needle) in \(String(decoding: buffer.readableBytesView, as: Unicode.UTF8.self))")
                }
                throw _IncompleteMessage()
            }

            assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
            if actual == needle {
                // great, we just match
                return
            } else if !caseSensitive {
                // we know this is all ASCII so we can do an ASCII case-insensitive compare here
                guard needleCount == actual.utf8.count,
                    actual.utf8.elementsEqual(needle.utf8, by: { ($0 & 0xDF) == ($1 & 0xDF) }) else {
                    throw ParserError(hint: "case insensitively looking for \(needle) found \(actual)")
                }
                return
            } else {
                throw ParserError(hint: "case sensitively looking for \(needle) found \(actual)")
            }
        }
    }

    static func oneOf<T>(_ subParsers: [SubParser<T>], buffer: inout ByteBuffer, tracker: StackTracker, file: String = (#file), line: Int = #line) throws -> T {
        for parser in subParsers {
            do {
                return try composite(buffer: &buffer, tracker: tracker, parser)
            } catch is ParserError {
                continue
            }
        }
        throw ParserError(hint: "none of the options match", file: file, line: line)
    }

    static func optional<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> T? {
        do {
            return try composite(buffer: &buffer, tracker: tracker, parser)
        } catch is ParserError {
            return nil
        }
    }

    static func composite<T>(buffer: inout ByteBuffer, tracker: StackTracker, _ body: SubParser<T>) throws -> T {
        var tracker = tracker
        try tracker.newStackFrame()

        let save = buffer
        do {
            return try body(&buffer, tracker)
        } catch {
            buffer = save
            throw error
        }
    }

    static func newline(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        switch buffer.getInteger(at: buffer.readerIndex, as: UInt16.self) {
        case .some(UInt16(0x0D0A /* CRLF */ )):
            // fast path: we find CRLF
            buffer.moveReaderIndex(forwardBy: 2)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\n"):
            // other fast path: we find LF + some other byte
            buffer.moveReaderIndex(forwardBy: 1)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: " "):
            // found a space that we’ll skip. Some servers insert an extra space at the end.
            try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
                buffer.moveReaderIndex(forwardBy: 1)
                try newline(buffer: &buffer, tracker: tracker)
            }
        case .none:
            guard let first = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch first {
            case UInt8(ascii: "\n"):
                buffer.moveReaderIndex(forwardBy: 1)
                return
            case UInt8(ascii: "\r"):
                throw _IncompleteMessage()
            default:
                // found only one byte which is neither CR nor LF.
                throw ParserError()
            }
        default:
            // found two bytes but they're neither CRLF, nor start with a NL.
            throw ParserError()
        }
    }
}
