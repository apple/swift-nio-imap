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
enum GrammarParser {}

// MARK: - Grammar Parsers

extension GrammarParser {
    /// Attempts to select a parser from the given `parsers` by extracting the first unbroken sequence of alpha characters.
    /// E.g. for the command `LOGIN username password`, the parser will parse `LOGIN`, and use that as a (case-insensitive) key to find a suitable parser in `parsers`.
    /// - parameter buffer: The `ByteBuffer` to parse from.
    /// - parameter tracker: Used to limit the stack depth.
    /// - parameter parsers: A dictionary that maps a string to a sub-parser.
    /// - returns: `T` if a suitable sub-parser was located and executed.
    /// - throws: A `ParserError` if a parser wasn't found.
    static func parseFromLookupTable<T>(buffer: inout ParseBuffer, tracker: StackTracker, parsers: [String: (inout ParseBuffer, StackTracker) throws -> T]) throws -> T {
        let save = buffer
        do {
            let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAlpha
            }
            let word = String(buffer: parsed).uppercased()
            guard let parser = parsers[word] else {
                throw ParserError(hint: "Didn't find parser for \(word)")
            }
            return try parser(&buffer, tracker)
        } catch {
            buffer = save
            throw error
        }
    }

    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try self.oneOf([
            Self.parseString,
            parseOneOrMoreASTRINGCHAR,
        ], buffer: &buffer, tracker: tracker)
    }

    // atom            = 1*ATOM-CHAR
    static func parseAtom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar
        }
        return String(buffer: parsed)
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    static func parseAttributeFlag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
        func parseAttributeFlag_slashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            try self.fixedString("\\\\", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(atom)
        }

        return try self.oneOf([
            parseAttributeFlag_slashed,
            parseAttributeFlag_unslashed,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAuthenticatedURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthenticatedURL in
            try self.fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try self.fixedString("/", buffer: &buffer, tracker: tracker)
            let messagePart = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePart: messagePart)
        }
    }

    static func parseAuthIMAPURLFull(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullAuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> FullAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(imapURL: imapURL, authenticatedURL: urlAuth)
        }
    }

    static func parseAuthIMAPURLRump(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpAuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> RumpAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let rump = try self.parseIRumpAuthenticatedURL(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: imapURL, authenticatedURLRump: rump)
        }
    }

    static func parseInitialClientResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialClientResponse {
        func parseInitialClientResponse_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            try self.fixedString("=", buffer: &buffer, tracker: tracker)
            return .empty
        }

        func parseInitialClientResponse_data(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .init(base64)
        }

        return try self.oneOf([
            parseInitialClientResponse_empty,
            parseInitialClientResponse_data,
        ], buffer: &buffer, tracker: tracker)
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try self.zeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq ..< readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }

            do {
                let decoded = try Base64.decode(bytes: bytes.readableBytesView)
                return ByteBuffer(bytes: decoded)
            } catch {
                throw ParserError(hint: "Invalid base64 \(error)")
            }
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    static func parseCapability(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    static func parseCapabilityData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try self.fixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try self.oneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // charset          = atom / quoted
    static func parseCharset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        func parseCharset_atom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseCharset_quoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            return string
        }

        return try self.oneOf([
            parseCharset_atom,
            parseCharset_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseChangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ChangedSinceModifier {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ChangedSinceModifier in
            try self.fixedString("CHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    static func parseUnchangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UnchangedSinceModifier {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> UnchangedSinceModifier in
            try self.fixedString("UNCHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try self.fixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try self.fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinuationRequest(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ContinuationRequest {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinuationRequest in
            try self.fixedString("+", buffer: &buffer, tracker: tracker)
            // Allow no space and no additional text after "+":
            let req: ContinuationRequest
            if try self.optional(buffer: &buffer, tracker: tracker, parser: self.spaces) != nil {
                if let base64 = try? self.parseBase64(buffer: &buffer, tracker: tracker), base64.readableBytes > 0 {
                    req = .data(base64)
                } else {
                    req = .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
                }
            } else {
                req = .responseText(ResponseText(code: nil, text: ""))
            }
            try self.newline(buffer: &buffer, tracker: tracker)
            return req
        }
    }

    // create-param = create-param-name [SP create-param-value]
    static func parseCreateParameters(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { buffer, tracker in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseCreateParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
        func parseCreateParameter_parameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
            try self.fixedString("USE (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        return try self.oneOf([
            parseCreateParameter_specialUse,
            parseCreateParameter_parameter,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue?> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: value)
        }
    }

    static func parseUseAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
        func parseUseAttribute_fixed(expected: String, returning: UseAttribute, buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try self.fixedString(expected, buffer: &buffer, tracker: tracker)
            return returning
        }

        func parseUseAttribute_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\All", returning: .all, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_archive(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Archive", returning: .archive, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_drafts(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Drafts", returning: .drafts, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_flagged(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Flagged", returning: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_junk(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Junk", returning: .junk, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_sent(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Sent", returning: .sent, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_trash(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Trash", returning: .trash, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try self.fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\" + att)
        }

        return try self.oneOf([
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

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try self.fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    static func parseEncodedAuthenticationType(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedAuthenticationType {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedAuthenticationType in
            let array = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(authenticationType: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedMailbox {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedMailbox in
            let array = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(mailbox: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSearch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSearch {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSearch in
            let array = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(query: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSection {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSection in
            let array = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(section: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedUser {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedUser in
            let array = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(data: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedAuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, _ -> EncodedAuthenticatedURL in
            let bytes = try self.bytes(buffer: &buffer, tracker: tracker, length: 32)
            guard bytes.readableBytesView.allSatisfy({ $0.isHexCharacter }) else {
                throw ParserError(hint: "Found invalid character in \(String(buffer: bytes))")
            }
            return .init(data: String(buffer: bytes))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try self.fixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try self.zeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)

    static func parseExtendedSearchResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtendedSearchResponse {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.fixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try self.zeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ExtendedSearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    static func parseExpire(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Expire {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Expire in
            try self.fixedString(";EXPIRE=", buffer: &buffer, tracker: tracker)
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    static func parseAccess(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
        func parseAccess_submit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try self.fixedString("submit+", buffer: &buffer, tracker: tracker)
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try self.fixedString("user+", buffer: &buffer, tracker: tracker)
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authenticatedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try self.fixedString("authuser", buffer: &buffer, tracker: tracker)
            return .authenticateUser
        }

        func parseAccess_anonymous(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try self.fixedString("anonymous", buffer: &buffer, tracker: tracker)
            return .anonymous
        }

        return try self.oneOf([
            parseAccess_submit,
            parseAccess_user,
            parseAccess_authenticatedUser,
            parseAccess_anonymous,
        ], buffer: &buffer, tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    static func parseFilterName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
        return String(buffer: parsed)
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    static func parseFlag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
        func parseFlag_answered(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            try self.fixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            try self.fixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            try self.fixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            try self.fixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            try self.fixedString("\\Draft", buffer: &buffer, tracker: tracker)
            return .draft
        }

        func parseFlag_keyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        return try self.oneOf([
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
    static func parseFlagExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try self.fixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try self.zeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try self.fixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try self.fixedString(")", allowLeadingSpaces: true, buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    static func parseFlagPerm(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try self.fixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseFlagPerm_wildcard,
            parseFlagPerm_flag,
        ], buffer: &buffer, tracker: tracker)
    }

    // header-fld-name = astring
    static func parseHeaderFieldName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    static func parseHeaderList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    static func parseICommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ICommand {
        func parseICommand_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ICommand {
            .messageList(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseICommand_part(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ICommand {
            let part = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            let auth = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIURLAuth)
            return .messagePart(part: part, authenticatedURL: auth)
        }

        return try self.oneOf([
            parseICommand_part,
            parseICommand_list,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseINetworkPath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> INetworkPath {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> INetworkPath in
            try self.fixedString("//", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseLastCommandSet<T: _IMAPEncodable>(buffer: inout ParseBuffer, tracker: StackTracker, setParser: SubParser<T>) throws -> LastCommandSet<T> {
        func parseLastCommandSet_lastCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            try self.fixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        func parseLastCommandSet_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            .set(try setParser(&buffer, tracker))
        }

        return try withoutActuallyEscaping(parseLastCommandSet_set) { (parseLastCommandSet_set) in
            try self.oneOf([
                parseLastCommandSet_lastCommand,
                parseLastCommandSet_set,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    static func parseIAbsolutePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IAbsolutePath {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> IAbsolutePath in
            try self.fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseIAuthentication(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IAuthentication {
        func parseIAuthentication_any(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IAuthentication {
            try self.fixedString("*", buffer: &buffer, tracker: tracker)
            return .any
        }

        func parseIAuthentication_encoded(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IAuthentication {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString(";AUTH=", buffer: &buffer, tracker: tracker)
            return try self.oneOf([
                parseIAuthentication_any,
                parseIAuthentication_encoded,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    static func parseIDParamsList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
        func parseIDParamsList_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (String, ByteBuffer?) {
            let key = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try self.spaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return (key, value)
        }

        func parseIDParamsList_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
            try self.fixedString("()", buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ByteBuffer?> {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let (key, value) = try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            var dic: KeyValues<String, ByteBuffer?> = [key: value]
            try self.zeroOrMore(buffer: &buffer, into: &dic, tracker: tracker) { (buffer, tracker) -> (String, ByteBuffer?) in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return dic
        }

        return try self.oneOf([
            parseIDParamsList_nil,
            parseIDParamsList_empty,
            parseIDParamsList_some,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIdleDone(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try self.fixedString("DONE", buffer: &buffer, tracker: tracker)
        try self.newline(buffer: &buffer, tracker: tracker)
    }

    static func parseIPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IPartial {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try self.fixedString("/", buffer: &buffer, tracker: tracker)
            return try parseIPartialOnly(buffer: &buffer, tracker: tracker)
        }
    }

    static func parseIPartialOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IPartial {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try self.fixedString(";PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIPathQuery(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IPathQuery {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPathQuery in
            try self.fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseISection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ISection {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISection in
            try self.fixedString("/;SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseISectionOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ISection {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISection in
            try self.fixedString(";SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIMAPServer(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPServer {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPServer in
            let info = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UserInfo in
                let info = try self.parseUserInfo(buffer: &buffer, tracker: tracker)
                try self.fixedString("@", buffer: &buffer, tracker: tracker)
                return info
            })
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try self.fixedString(":", buffer: &buffer, tracker: tracker)
                return try self.parseNumber(buffer: &buffer, tracker: tracker)
            })
            return .init(userInfo: info, host: host, port: port)
        }
    }

    static func parseHost(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_ipv6(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_future(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseHost_literal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try self.fixedString("[", buffer: &buffer, tracker: tracker)
            let address = try self.oneOf([
                parseHost_ipv6,
                parseHost_future,
            ], buffer: &buffer, tracker: tracker)
            try self.fixedString("]", buffer: &buffer, tracker: tracker)
            return address
        }

        func parseHost_regularName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            var newBuffer = ByteBuffer()
            while true {
                do {
                    // FIXME: This is very inefficient
                    let chars = try self.parseUChar(buffer: &buffer, tracker: tracker)
                    newBuffer.writeBytes(chars)
                } catch is ParserError {
                    break
                }
            }
            return String(buffer: newBuffer)
        }

        // TODO: This isn't great, but it is functional. Perhaps make it actually enforce IPv4 rules
        func parseHost_ipv4(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            let num3 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            let num4 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return "\(num1).\(num2).\(num3).\(num4)"
        }

        return try self.oneOf([
            parseHost_literal,
            parseHost_regularName,
            parseHost_ipv4,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMailboxReference(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMailboxReference {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMailboxReference in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UIDValidity in
                try self.fixedString(";UIDVALIDITY=", buffer: &buffer, tracker: tracker)
                return try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            })
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    static func parseIMessageList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageList {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessageList in
            let mailboxRef = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let query = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> EncodedSearch in
                try self.fixedString("?", buffer: &buffer, tracker: tracker)
                return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
            })
            return .init(mailboxReference: mailboxRef, encodedSearch: query)
        }
    }

    static func parseIMAPURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPURL in
            try self.fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseRelativeIMAPURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
        func parseRelativeIMAPURL_absolute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .absolutePath(try self.parseIAbsolutePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_network(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .networkPath(try self.parseINetworkPath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_relative(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .relativePath(try self.parseIRelativePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .empty
        }

        return try self.oneOf([
            parseRelativeIMAPURL_network,
            parseRelativeIMAPURL_absolute,
            parseRelativeIMAPURL_relative,
            parseRelativeIMAPURL_empty,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIRelativePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IRelativePath {
        func parseIRelativePath_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IRelativePath {
            .list(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseIRelativePath_messageOrPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IRelativePath {
            .messageOrPartial(try self.parseIMessageOrPartial(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseIRelativePath_list,
            parseIRelativePath_messageOrPartial,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMessagePart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessagePart {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessagePart in
            var ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)

            var uid = IUID(uid: 1)
            if ref.uidValidity == nil, ref.encodedMailbox.mailbox.last == Character(.init(UInt8(ascii: "/"))) {
                try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    ref.encodedMailbox.mailbox = String(ref.encodedMailbox.mailbox.dropLast())

                    uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
                }
            } else {
                uid = try self.parseIUID(buffer: &buffer, tracker: tracker)
            }

            var section = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseISection)
            var partial: IPartial?
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    section!.encodedSection.section = String(section!.encodedSection.section.dropLast())

                    partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                }
            } else {
                partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartial)
            }
            return .init(mailboxReference: ref, iUID: uid, iSection: section, iPartial: partial)
        }
    }

    static func parseIMessageOrPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
        func parseIMessageOrPartial_partialOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let partial = try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseIMessageOrPartial_sectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            var section = try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            if section.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section.encodedSection.section = String(section.encodedSection.section.dropLast())
                do {
                    let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .sectionPartial(section: section, partial: partial)
                } catch is ParserError {
                    section.encodedSection.section.append("/")
                    return .sectionPartial(section: section, partial: nil)
                }
            }
            let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try self.fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .sectionPartial(section: section, partial: partial)
        }

        func parseIMessageOrPartial_uidSectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISection in
                try self.fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .uidSectionPartial(uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .uidSectionPartial(uid: uid, section: section, partial: nil)
                }
            }
            let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try self.fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseIMessageOrPartial_refUidSectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISection in
                try self.fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: nil)
                }
            }
            let partial = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try self.fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        return try self.oneOf([
            parseIMessageOrPartial_refUidSectionPartial,
            parseIMessageOrPartial_uidSectionPartial,
            parseIMessageOrPartial_sectionPartial,
            parseIMessageOrPartial_partialOnly,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseUChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try self.byte(buffer: &buffer, tracker: tracker)
            guard num.isUnreserved else {
                throw ParserError(hint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try self.byte(buffer: &buffer, tracker: tracker)
            guard num.isSubDelimsSh else {
                throw ParserError(hint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            // FIXME: Better parser for this
            try self.fixedString("%", buffer: &buffer, tracker: tracker)
            var h1 = try self.byte(buffer: &buffer, tracker: tracker)
            var h2 = try self.byte(buffer: &buffer, tracker: tracker)

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

        return try self.oneOf([
            parseUChar_unreserved,
            parseUChar_subDelimsSH,
            parseUChar_pctEncoded,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseAChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try self.byte(buffer: &buffer, tracker: tracker)
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw ParserError(hint: "Expect achar, got \(char)")
            }
        }

        return try self.oneOf([
            parseUChar,
            parseAChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseBChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseBChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try self.byte(buffer: &buffer, tracker: tracker)
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw ParserError(hint: "Expect bchar, got \(char)")
            }
        }

        return try self.oneOf([
            parseAChar,
            parseBChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIUID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("/", buffer: &buffer, tracker: tracker)
            return try parseIUIDOnly(buffer: &buffer, tracker: tracker)
        }
    }

    static func parseIUIDOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString(";UID=", buffer: &buffer, tracker: tracker)
            return IUID(uid: try self.parseUID(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IAuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IAuthenticatedURL in
            let rump = try self.parseIRumpAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseAuthenticatedURLVerifier(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: rump, verifier: verifier)
        }
    }

    static func parseURLRumpMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpURLAndMechanism {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> RumpURLAndMechanism in
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    static func parseURLFetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchData {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLFetchData in
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let data = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(url: url, data: data)
        }
    }

    static func parseIRumpAuthenticatedURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IRumpAuthenticatedURL {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IRumpAuthenticatedURL in
            let expiry = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseExpire)
            try self.fixedString(";URLAUTH=", buffer: &buffer, tracker: tracker)
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    static func parseAuthenticatedURLVerifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURLVerifier {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthenticatedURLVerifier in
            try self.fixedString(":", buffer: &buffer, tracker: tracker)
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try self.fixedString(":", buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(urlAuthMechanism: authMechanism, encodedAuthenticationURL: urlAuth)
        }
    }

    static func parseUserInfo(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UserInfo {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UserInfo in
            let encodedUser = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseEncodedUser)
            let authenticationMechanism = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseIAuthentication)
            guard (encodedUser != nil || authenticationMechanism != nil) else {
                throw ParserError(hint: "Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, authenticationMechanism: authenticationMechanism)
        }
    }

    static func parseFullDateTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDateTime {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try self.fixedString("T", buffer: &buffer, tracker: tracker)
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    static func parseFullDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDate {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try self.fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try self.fixedString("-", buffer: &buffer, tracker: tracker)
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    static func parseFullTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try self.fixedString(":", buffer: &buffer, tracker: tracker)
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try self.fixedString(":", buffer: &buffer, tracker: tracker)
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try self.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        })
        return .init(hour: hour, minute: minute, second: second, fraction: fraction)
    }

    static func parseLiteralSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.fixedString("~", buffer: &buffer, tracker: tracker)
            }
            try self.fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.fixedString("}", buffer: &buffer, tracker: tracker)
            try self.newline(buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try self.fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try self.fixedString("}", buffer: &buffer, tracker: tracker)
            try self.newline(buffer: &buffer, tracker: tracker)
            let bytes = try self.bytes(buffer: &buffer, tracker: tracker, length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral8(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try self.fixedString("~{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try self.fixedString("}", buffer: &buffer, tracker: tracker)
            try self.newline(buffer: &buffer, tracker: tracker)
            let bytes = try self.bytes(buffer: &buffer, tracker: tracker, length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Kind_defined(_ option: String, result: Media.BasicKind, buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            try self.fixedString(option, buffer: &buffer, tracker: tracker)
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Kind_application(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_audio(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_image(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_message(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_video(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(String(buffer: buffer))
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try self.oneOf([
                parseMediaBasic_Kind_application,
                parseMediaBasic_Kind_audio,
                parseMediaBasic_Kind_image,
                parseMediaBasic_Kind_message,
                parseMediaBasic_Kind_video,
                parseMediaBasic_Kind_other,
            ], buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(kind: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Message {
            try self.fixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try self.fixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try self.oneOf([
                parseMediaMessage_rfc,
            ], buffer: &buffer, tracker: tracker)
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.MediaSubtype {
        let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        let string = String(buffer: buffer)
        return .init(string)
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try self.fixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseString(buffer: &buffer, tracker: tracker)
            return String(buffer: subtype)
        }
    }

    static func parseMetadataOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
        func parseMetadataOption_maxSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            try self.fixedString("MAXSIZE ", buffer: &buffer, tracker: tracker)
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseMetadataOption_maxSize,
            parseMetadataOption_scope,
            parseMetadataOption_param,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataOption] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
            })
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseMetadataResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
        func parseMetadataResponse_values(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try self.fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try self.fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try self.oneOf([
            parseMetadataResponse_values,
            parseMetadataResponse_list,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
        func parseMetadataValue_nstring(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataValue_literal8(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseLiteral8(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseMetadataValue_nstring,
            parseMetadataValue_literal8,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMechanismBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MechanismBase64 {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MechanismBase64 in
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try self.optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
                try self.fixedString("=", buffer: &buffer, tracker: tracker)
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    static func parseGmailLabel(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
        func parseGmailLabel_backslash(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            try self.fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(ByteBuffer(string: "\\\(att)"))
        }

        func parseGmailLabel_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(raw)
        }

        return try self.oneOf([
            parseGmailLabel_backslash,
            parseGmailLabel_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try self.oneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try self.oneOf([
            parseNamespace_nil,
            parseNamespace_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Character? {
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            let char = try self.byte(buffer: &buffer, tracker: tracker)
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let char = try self.oneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(string: string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    static func parseNamespaceResponseExtensions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<ByteBuffer, [ByteBuffer]> {
        var kvs = KeyValues<ByteBuffer, [ByteBuffer]>()
        try self.zeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
        return kvs
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    static func parseNamespaceResponseExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<ByteBuffer, [ByteBuffer]> {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try self.spaces(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(key: s1, value: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try self.fixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try self.fixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.fixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try self.oneOf([
            parseNString_nil,
            parseNString_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // number          = 1*DIGIT
    static func parseNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try self.unsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    static func parseNZNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.unsignedInteger(buffer: &buffer, tracker: tracker).number
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    static func parseOptionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<OptionExtensionKind, OptionValueComp?> {
        func parseOptionExtensionKind_standard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .standard(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionKind_vendor(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<OptionExtensionKind, OptionValueComp?> in
            let type = try self.oneOf([
                parseOptionExtensionKind_standard,
                parseOptionExtensionKind_vendor,
            ], buffer: &buffer, tracker: tracker)
            let value = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try self.oneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, String> {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, String> in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try self.fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(key: token, value: atom)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ClosedRange<UInt32> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
            try self.fixedString("<", buffer: &buffer, tracker: tracker)
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try self.fixedString(">", buffer: &buffer, tracker: tracker)
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return num1 ... upper2.partialValue
        }
    }

    static func parsePartialRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PartialRange {
        func parsePartialRange_length(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
            try self.fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> PartialRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try self.optional(buffer: &buffer, tracker: tracker, parser: parsePartialRange_length)
            return .init(offset: offset, length: length)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try self.zeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try self.fixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try self.fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try self.fixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseScopeOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
        func parseScopeOption_zero(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try self.fixedString("0", buffer: &buffer, tracker: tracker)
            return .zero
        }

        func parseScopeOption_one(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try self.fixedString("1", buffer: &buffer, tracker: tracker)
            return .one
        }

        func parseScopeOption_infinity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try self.fixedString("infinity", buffer: &buffer, tracker: tracker)
            return .infinity
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("DEPTH ", buffer: &buffer, tracker: tracker)
            return try self.oneOf([
                parseScopeOption_zero,
                parseScopeOption_one,
                parseScopeOption_infinity,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSection_none(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier in
                try self.fixedString("[]", buffer: &buffer, tracker: tracker)
                return .complete
            }
        }

        func parseSection_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try self.fixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try self.fixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }

        return try self.oneOf([
            parseSection_none,
            parseSection_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try self.fixedString("[", buffer: &buffer, tracker: tracker)
            let part = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseSectionPart)
            try self.fixedString("]", buffer: &buffer, tracker: tracker)
            return part ?? .init([])
        }
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try self.fixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpecifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            return .init(kind: kind)
        }

        func parseSectionSpecifier_withPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                try self.fixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try self.oneOf([
            parseSectionSpecifier_withPart,
            parseSectionSpecifier_noPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionSpecifierKind(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try self.fixedString("MIME", buffer: &buffer, tracker: tracker)
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try self.fixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionSpecifierKind_headerFields(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try self.fixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try self.fixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try self.fixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        func parseSectionSpecifierKind_complete(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try self.oneOf([
            parseSectionSpecifierKind_mime,
            parseSectionSpecifierKind_headerFields,
            parseSectionSpecifierKind_notHeaderFields,
            parseSectionSpecifierKind_header,
            parseSectionSpecifierKind_text,
            parseSectionSpecifierKind_complete,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseSelectParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
        func parseSelectParameter_basic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try self.fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
            return .condstore
        }

        func parseSelectParameter_qresync(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try self.fixedString("QRESYNC (", buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUids = try self.optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> LastCommandSet<SequenceRangeSet> in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseKnownUids(buffer: &buffer, tracker: tracker)
            })
            let seqMatchData = try self.optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceMatchData in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseSequenceMatchData(buffer: &buffer, tracker: tracker)
            })
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .qresync(.init(uidValiditiy: uidValidity, modificationSequenceValue: modSeqVal, knownUids: knownUids, sequenceMatchData: seqMatchData))
        }

        return try self.oneOf([
            parseSelectParameter_qresync,
            parseSelectParameter_condstore,
            parseSelectParameter_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseKnownUids(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<SequenceRangeSet> {
        try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseParameters(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<String, ParameterValue?> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> KeyValues<String, ParameterValue?> in
            try self.fixedString(" (", buffer: &buffer, tracker: tracker)
            var kvs = KeyValues<String, ParameterValue?>()
            kvs.append(try self.parseParameter(buffer: &buffer, tracker: tracker))
            try self.zeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> KeyValue<String, ParameterValue?> in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return kvs
        }
    }

    static func parseSortData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SortData? {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SortData? in
            try self.fixedString("SORT", buffer: &buffer, tracker: tracker)
            let _components = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ([Int], ModificationSequenceValue) in
                try self.spaces(buffer: &buffer, tracker: tracker)
                var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
                try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try self.spaces(buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                })
                try self.spaces(buffer: &buffer, tracker: tracker)
                let seq = try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
                return (array, seq)
            }

            guard let components = _components else {
                return nil
            }
            return SortData(identifiers: components.0, modificationSequence: components.1)
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    static func parseStatusAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        let string = String(buffer: parsed)
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try self.fixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseStoreModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
        func parseFetchModifier_unchangedSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseFetchModifier_unchangedSince,
            parseFetchModifier_other,
        ], buffer: &buffer, tracker: tracker)
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreAttributeFlags_silent(buffer: inout ParseBuffer, tracker: StackTracker) -> Bool {
            do {
                try self.fixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
            try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try self.zeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Flag in
                    try self.spaces(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_operation(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreFlags.Operation {
            try self.oneOf([
                { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try self.fixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try self.fixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try self.fixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .replace
                },
            ], buffer: &buffer, tracker: tracker)
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> StoreFlags in
            let operation = try parseStoreAttributeFlags_operation(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let flags = try self.oneOf([
                parseStoreAttributeFlags_array,
                parseFlagList,
            ], buffer: &buffer, tracker: tracker)
            return StoreFlags(operation: operation, silent: silent, flags: flags)
        }
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.oneOf([
            Self.parseQuoted,
            Self.parseLiteral,
        ], buffer: &buffer, tracker: tracker)
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    static func parseTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parser = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAStringChar && char != UInt8(ascii: "+")
        }
        return String(buffer: parser)
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let key = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if key.lowercased() == "catenate" {
                throw ParserError(hint: "catenate extension")
            }

            try self.spaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseParameterName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            let fchar = try self.byte(buffer: &buffer, tracker: tracker)
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let parsed = try self.zeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isTaggedLabelChar
            }
            let trailing = String(buffer: parsed)

            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    static func parseTaggedExtensionComplex_continuation(
        into: inout [String],
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws {
        while true {
            do {
                try self.spaces(buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                return
            }
        }
    }

    static func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws {
            into.append(String(buffer: try self.parseAString(buffer: &buffer, tracker: tracker)))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws {
            try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.fixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try self.fixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
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
    static func parseTaggedExtensionComplex(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseParameterValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
        func parseTaggedExtensionSimple_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
            .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.optional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try self.oneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionVal_comp,
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    static func parseUAuthMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLAuthenticationMechanism {
        let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker, where: { char in
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
        let string = String(buffer: parsed)
        return URLAuthenticationMechanism(string)
    }

    // userid          = astring
    static func parseUserId(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var astring = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return astring.readString(length: astring.readableBytes)! // if this fails, something has gone very, very wrong
    }

    // vendor-token     = atom (maybe?!?!?!)
    static func parseVendorToken(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try self.oneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAlpha
        }
        return String(buffer: parsed)
    }

    // setquota_list   ::= "(" 0#setquota_resource ")"
    static func parseQuotaLimits(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [QuotaLimit] {
        // setquota_resource ::= atom SP number
        func parseQuotaLimit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaLimit {
            try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.optional(buffer: &buffer, tracker: tracker, parser: self.spaces)
                let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                try self.spaces(buffer: &buffer, tracker: tracker)
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaLimit(resourceName: resourceName, limit: limit)
            }
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) throws -> [QuotaLimit] in
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            let limits = try self.zeroOrMore(buffer: &buffer, tracker: tracker, parser: parseQuotaLimit)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return limits
        }
    }

    static func parseQuotaRoot(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaRoot {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return QuotaRoot(string)
    }

    // RFC 5465
    // one-or-more-mailbox = mailbox / many-mailboxes
    static func parseOneOrMoreMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
        // many-mailboxes  = "(" mailbox *(SP mailbox) ")
        func parseManyMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while try self.optional(buffer: &buffer, tracker: tracker, parser: self.spaces) != nil {
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap mailboxes which should be impossible")
            }
        }

        func parseSingleMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
            let mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap single mailboxes which should be impossible")
            }
        }

        return try self.oneOf([
            parseManyMailboxes,
            parseSingleMailboxes,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    static func parseFilterMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("selected", buffer: &buffer, tracker: tracker)
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("selected-delayed", buffer: &buffer, tracker: tracker)
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("inboxes", buffer: &buffer, tracker: tracker)
            return .inboxes
        }

        func parseFilterMailboxes_Personal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("personal", buffer: &buffer, tracker: tracker)
            return .personal
        }

        func parseFilterMailboxes_Subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("subscribed", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("subtree ", buffer: &buffer, tracker: tracker)
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("mailboxes ", buffer: &buffer, tracker: tracker)
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 6237
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try self.fixedString("subtree-one ", buffer: &buffer, tracker: tracker)
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
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
    static func parseExtendedSearchScopeOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtendedSearchScopeOptions {
        var options = KeyValues<String, ParameterValue?>()
        options.append(try parseParameter(buffer: &buffer, tracker: tracker))
        while try self.optional(buffer: &buffer, tracker: tracker, parser: self.spaces) != nil {
            options.append(try parseParameter(buffer: &buffer, tracker: tracker))
        }
        if let returnValue = ExtendedSearchScopeOptions(options) {
            return returnValue
        } else {
            throw ParserError(hint: "Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
    }

    // RFC 6237
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    static func parseExtendedSearchSourceOptions(buffer: inout ParseBuffer,
                                                 tracker: StackTracker) throws -> ExtendedSearchSourceOptions
    {
        func parseExtendedSearchSourceOptions_spaceFilter(buffer: inout ParseBuffer,
                                                          tracker: StackTracker) throws -> MailboxFilter
        {
            try self.spaces(buffer: &buffer, tracker: tracker)
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseExtendedSearchSourceOptions_sourceMBox(buffer: inout ParseBuffer,
                                                         tracker: StackTracker) throws -> [MailboxFilter]
        {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            while let anotherSource = try self.optional(buffer: &buffer,
                                                                 tracker: tracker,
                                                                 parser: parseExtendedSearchSourceOptions_spaceFilter)
            {
                sources.append(anotherSource)
            }
            return sources
        }

        func parseExtendedSearchSourceOptions_scopeOptions(buffer: inout ParseBuffer,
                                                           tracker: StackTracker) throws -> ExtendedSearchScopeOptions
        {
            try self.fixedString(" (", buffer: &buffer, tracker: tracker)
            let result = try parseExtendedSearchScopeOptions(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.fixedString("IN (", buffer: &buffer, tracker: tracker)
            let sourceMbox = try parseExtendedSearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try self.optional(buffer: &buffer,
                                                          tracker: tracker,
                                                          parser: parseExtendedSearchSourceOptions_scopeOptions)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            if let result = ExtendedSearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) {
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
    static func parseExtendedSearchOptions(buffer: inout ParseBuffer,
                                           tracker: StackTracker) throws -> ExtendedSearchOptions
    {
        func parseExtendedSearchOptions_sourceOptions(buffer: inout ParseBuffer,
                                                      tracker: StackTracker) throws -> ExtendedSearchSourceOptions
        {
            try self.spaces(buffer: &buffer, tracker: tracker)
            let result = try parseExtendedSearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try self.optional(buffer: &buffer,
                                                       tracker: tracker,
                                                       parser: parseExtendedSearchOptions_sourceOptions)
        let returnOpts = try self.optional(buffer: &buffer,
                                                    tracker: tracker,
                                                    parser: self.parseSearchReturnOptions) ?? []
        try self.spaces(buffer: &buffer, tracker: tracker)
        let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
        return ExtendedSearchOptions(key: program, charset: charset, returnOptions: returnOpts, sourceOptions: sourceOptions)
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    static func parse2Digit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ParseBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let (num, size) = try self.unsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
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

// MARK: - ParserLibrary shortcuts
extension GrammarParser {

    static func oneOrMoreCharacters(buffer: inout ParseBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> ByteBuffer {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker, where: `where`)
    }

    static func zeroOrMoreCharacters(buffer: inout ParseBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> ByteBuffer {
        try ParserLibrary.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker, where: `where`)
    }

    static func oneOrMore<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: parser)
    }

    static func oneOrMore<T>(buffer: inout ParseBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try ParserLibrary.parseOneOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
    }

    static func zeroOrMore<T>(buffer: inout ParseBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
    }

    static func zeroOrMore<K, V>(buffer: inout ParseBuffer, into keyValues: inout KeyValues<K, V>, tracker: StackTracker, parser: SubParser<(K, V)>) throws {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &keyValues, tracker: tracker, parser: parser)
    }

    static func zeroOrMore<K, V>(buffer: inout ParseBuffer, into keyValues: inout KeyValues<K, V>, tracker: StackTracker, parser: SubParser<KeyValue<K, V>>) throws {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &keyValues, tracker: tracker, parser: parser)
    }

    static func zeroOrMore<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: parser)
    }

    static func unsignedInteger(buffer: inout ParseBuffer, tracker: StackTracker, allowLeadingZeros: Bool = false) throws -> (number: Int, bytesConsumed: Int) {
        try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: allowLeadingZeros)
    }

    static func unsignedInt64(buffer: inout ParseBuffer, tracker: StackTracker, allowLeadingZeros: Bool = false) throws -> (number: UInt64, bytesConsumed: Int) {
        try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker, allowLeadingZeros: allowLeadingZeros)
    }

    static func spaces(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
    }

    static func fixedString(_ needle: String, caseSensitive: Bool = false, allowLeadingSpaces: Bool = false, buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try ParserLibrary.fixedString(needle, caseSensitive: caseSensitive, allowLeadingSpaces: allowLeadingSpaces, buffer: &buffer, tracker: tracker)
    }

    static func oneOf<T>(_ subParsers: [SubParser<T>], buffer: inout ParseBuffer, tracker: StackTracker, file: String = (#file), line: Int = #line) throws -> T {
        try ParserLibrary.oneOf(subParsers, buffer: &buffer, tracker: tracker, file: file, line: line)
    }

    static func oneOf<T>(_ parser1: SubParser<T>,
                          _ parser2: SubParser<T>,
                          buffer: inout ParseBuffer,
                          tracker: StackTracker, file: String = (#file), line: Int = #line) throws -> T
    {
        try ParserLibrary.oneOf2(parser1, parser2, buffer: &buffer, tracker: tracker)
    }

    static func oneOf<T>(_ parser1: SubParser<T>,
                          _ parser2: SubParser<T>,
                          _ parser3: SubParser<T>,
                          buffer: inout ParseBuffer,
                          tracker: StackTracker, file: String = (#file), line: Int = #line) throws -> T
    {
        try ParserLibrary.oneOf2(parser1, parser2, buffer: &buffer, tracker: tracker)
    }

    static func optional<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> T? {
        try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: parser)
    }

    static func composite<T>(buffer: inout ParseBuffer, tracker: StackTracker, _ body: SubParser<T>) throws -> T {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker, body)
    }

    static func newline(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try ParserLibrary.newline(buffer: &buffer, tracker: tracker)
    }

    static func byte(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UInt8 {
        try ParserLibrary.parseByte(buffer: &buffer, tracker: tracker)
    }

    static func bytes(buffer: inout ParseBuffer, tracker: StackTracker, length: Int) throws -> ByteBuffer {
        try ParserLibrary.parseBytes(buffer: &buffer, tracker: tracker, length: length)
    }

    static func bytes(buffer: inout ParseBuffer, tracker: StackTracker, upTo maxLength: Int) throws -> ByteBuffer {
        try ParserLibrary.parseBytes(buffer: &buffer, tracker: tracker, upTo: maxLength)
    }
}
