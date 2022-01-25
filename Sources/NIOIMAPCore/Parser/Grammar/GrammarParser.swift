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

public struct ExceededLiteralSizeLimitError: Error {}

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

struct GrammarParser {
    static let defaultParsedStringCache: (String) -> String = { str in
        str
    }

    var parsedStringCache: (String) -> String

    let literalSizeLimit: Int
    let messageBodySizeLimit: Int

    /// - parameter parseCache
    init(literalSizeLimit: Int = IMAPDefaults.literalSizeLimit, messageBodySizeLimit: Int = IMAPDefaults.bodySizeLimit, parsedStringCache: ((String) -> String)? = nil) {
        self.literalSizeLimit = literalSizeLimit
        self.messageBodySizeLimit = messageBodySizeLimit
        self.parsedStringCache = parsedStringCache ?? Self.defaultParsedStringCache
    }
}

typealias PL = ParserLibrary

// MARK: - Grammar Parsers

extension GrammarParser {
    /// Attempts to select a parser from the given `parsers` by extracting the first unbroken sequence of alpha characters.
    /// E.g. for the command `LOGIN username password`, the parser will parse `LOGIN`, and use that as a (case-insensitive) key to find a suitable parser in `parsers`.
    /// - parameter buffer: The `ByteBuffer` to parse from.
    /// - parameter tracker: Used to limit the stack depth.
    /// - parameter parsers: A dictionary that maps a string to a sub-parser.
    /// - returns: `T` if a suitable sub-parser was located and executed.
    /// - throws: A `ParserError` if a parser wasn't found.
    func parseFromLookupTable<T>(buffer: inout ParseBuffer, tracker: StackTracker, parsers: [String: (inout ParseBuffer, StackTracker) throws -> T]) throws -> T {
        let save = buffer
        do {
            let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                switch char {
                case _ where char.isAlphaNum, UInt8(ascii: "."), UInt8(ascii: "-"):
                    return true
                default:
                    return false
                }
            }
            let word = try ParserLibrary.parseBufferAsUTF8(parsed).uppercased()
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
    func parseAString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try PL.parseOneOf(
            self.parseString,
            parseOneOrMoreASTRINGCHAR,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // atom            = 1*ATOM-CHAR
    func parseAtom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar
        }
        let string = try ParserLibrary.parseBufferAsUTF8(parsed)
        return self.parsedStringCache(string)
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    func parseAttributeFlag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
        func parseAttributeFlag_slashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            try PL.parseFixedString("\\\\", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(atom)
        }

        return try PL.parseOneOf(
            parseAttributeFlag_slashed,
            parseAttributeFlag_unslashed,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseAuthenticatedURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NetworkMessagePath {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NetworkMessagePath in
            try PL.parseFixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            let messagePath = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePath: messagePath)
        }
    }

    func parseAuthIMAPURLFull(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullAuthenticatedURL {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> FullAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(networkMessagePath: imapURL, authenticatedURL: urlAuth)
        }
    }

    func parseAuthIMAPURLRump(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpAuthenticatedURL {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> RumpAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: imapURL, authenticatedURLRump: rump)
        }
    }

    func parseInitialResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
        func parseInitialResponse_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
            try PL.parseFixedString("=", buffer: &buffer, tracker: tracker)
            return .empty
        }

        func parseInitialResponse_data(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .init(base64)
        }

        return try PL.parseOneOf(
            parseInitialResponse_empty,
            parseInitialResponse_data,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // base64          = *(4base64-char) [base64-terminal]
    func parseBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try PL.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            do {
                let decoded = try Base64.decode(bytes: bytes.readableBytesView)
                return ByteBuffer(bytes: decoded)
            } catch {
                throw ParserError(hint: "Invalid base64 \(error)")
            }
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    func parseCapability(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    func parseCapabilityData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try PL.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try PL.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // charset          = atom / quoted
    func parseCharset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
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

        return try PL.parseOneOf(
            parseCharset_atom,
            parseCharset_quoted,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseChangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ChangedSinceModifier {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ChangedSinceModifier in
            try PL.parseFixedString("CHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    func parseUnchangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UnchangedSinceModifier {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> UnchangedSinceModifier in
            try PL.parseFixedString("UNCHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    func parseChildinfoExtendedItem(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try PL.parseFixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // condstore-param = "CONDSTORE"
    func parseConditionalStoreParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try PL.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    func parseContinuationRequest(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ContinuationRequest {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinuationRequest in
            try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
            // Allow no space and no additional text after "+":
            let req: ContinuationRequest
            if try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces) != nil {
                if let base64 = try? self.parseBase64(buffer: &buffer, tracker: tracker), base64.readableBytes > 0 {
                    req = .data(base64)
                } else {
                    req = .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
                }
            } else {
                req = .responseText(ResponseText(code: nil, text: ""))
            }
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return req
        }
    }

    // create-param = create-param-name [SP create-param-value]
    func parseCreateParameters(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    func parseCreateParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
        func parseCreateParameter_parameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
            try PL.parseFixedString("USE (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        return try PL.parseOneOf(
            parseCreateParameter_specialUse,
            parseCreateParameter_parameter,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue?> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: value)
        }
    }

    func parseUseAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
        func parseUseAttribute_fixed(expected: String, returning: UseAttribute, buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try PL.parseFixedString(expected, buffer: &buffer, tracker: tracker)
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
            try PL.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init("\\" + att)
        }

        return try PL.parseOneOf([
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
    func parseEitemVendorTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    func parseEncodedAuthenticationType(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedAuthenticationType {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedAuthenticationType in
            let array = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(authenticationType: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedMailbox {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedMailbox in
            let array = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(mailbox: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSearch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSearch {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSearch in
            let array = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(query: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSection {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSection in
            let array = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(section: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedUser {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedUser in
            let array = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(data: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedAuthenticatedURL {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, _ -> EncodedAuthenticatedURL in
            let bytes = try PL.parseBytes(buffer: &buffer, tracker: tracker, length: 32)
            guard bytes.readableBytesView.allSatisfy(\.isHexCharacter) else {
                throw ParserError(hint: "Found invalid character in \(String(buffer: bytes))")
            }

            // can used the unsafe String.init here as we've already validated everything is valid hex
            return .init(data: String(buffer: bytes))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    func parseEnableData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try PL.parseFixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)

    func parseExtendedSearchResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtendedSearchResponse {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseFixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ExtendedSearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    func parseExpire(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Expire {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Expire in
            try PL.parseFixedString(";EXPIRE=", buffer: &buffer, tracker: tracker)
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    func parseAccess(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
        func parseAccess_submit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try PL.parseFixedString("submit+", buffer: &buffer, tracker: tracker)
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try PL.parseFixedString("user+", buffer: &buffer, tracker: tracker)
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authenticatedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try PL.parseFixedString("authuser", buffer: &buffer, tracker: tracker)
            return .authenticateUser
        }

        func parseAccess_anonymous(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try PL.parseFixedString("anonymous", buffer: &buffer, tracker: tracker)
            return .anonymous
        }

        return try PL.parseOneOf([
            parseAccess_submit,
            parseAccess_user,
            parseAccess_authenticatedUser,
            parseAccess_anonymous,
        ], buffer: &buffer, tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    func parseFilterName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
        return try ParserLibrary.parseBufferAsUTF8(parsed)
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    func parseFlag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
        func parseFlag_keyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        return try PL.parseOneOf([
            parseFlag_keyword,
            parseFlag_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-extension  = "\" atom
    func parseFlagExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try PL.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    func parseFlagKeyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    func parseFlagList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try PL.parseFixedString(")", allowLeadingSpaces: true, buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    func

        parseFlagPerm(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag
    {
        func parseFlagPerm_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try PL.parseFixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseFlagPerm_wildcard,
            parseFlagPerm_flag,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // header-fld-name = astring
    func parseHeaderFieldName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    func parseHeaderList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    func parseURLCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
        func parseURLCommand_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
            .messageList(try self.parseEncodedSearchQuery(buffer: &buffer, tracker: tracker))
        }

        func parseURLCommand_part(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
            let path = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            let auth = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIURLAuth)
            return .fetch(path: path, authenticatedURL: auth)
        }

        return try PL.parseOneOf(
            parseURLCommand_part,
            parseURLCommand_list,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseNetworkPath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NetworkPath {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NetworkPath in
            try PL.parseFixedString("//", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            let command = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseURLCommand)
            return .init(server: server, query: command)
        }
    }

    func parseLastCommandSet<T: IMAPEncodable>(buffer: inout ParseBuffer, tracker: StackTracker, setParser: SubParser<T>) throws -> LastCommandSet<T> {
        func parseLastCommandSet_lastCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            try PL.parseFixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        func parseLastCommandSet_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            .set(try setParser(&buffer, tracker))
        }

        return try PL.parseOneOf(
            parseLastCommandSet_lastCommand,
            parseLastCommandSet_set,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseAbsoluteMessagePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AbsoluteMessagePath {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AbsoluteMessagePath in
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            let command = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseURLCommand)
            return .init(command: command)
        }
    }

    func parseIMAPURLAuthenticationMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURLAuthenticationMechanism {
        func parseIMAPURLAuthenticationMechanism_any(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURLAuthenticationMechanism {
            try PL.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .any
        }

        func parseIMAPURLAuthenticationMechanism_encoded(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURLAuthenticationMechanism {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString(";AUTH=", buffer: &buffer, tracker: tracker)
            return try PL.parseOneOf(
                parseIMAPURLAuthenticationMechanism_any,
                parseIMAPURLAuthenticationMechanism_encoded,
                buffer: &buffer,
                tracker: tracker
            )
        }
    }

    // id-response = "ID" SP id-params-list
    func parseIDResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    func parseIDParamsList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?> {
        func parseIDValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String? {
            if let value = try self.parseNString(buffer: &buffer, tracker: tracker) {
                return try ModifiedUTF7.decode(value)
            } else {
                return nil
            }
        }

        func parseIDParamsList_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?> {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (String, String?) {
            let parsedKey = try self.parseString(buffer: &buffer, tracker: tracker)
            let key = try ParserLibrary.parseBufferAsUTF8(parsedKey)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return (key, try parseIDValue(buffer: &buffer, tracker: tracker))
        }

        func parseIDParamsList_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?> {
            try PL.parseFixedString("()", buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?> {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let (key, value) = try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            var dic: OrderedDictionary<String, String?> = [key: value]
            try PL.parseZeroOrMore(buffer: &buffer, into: &dic, tracker: tracker) { (buffer, tracker) -> (String, String?) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return dic
        }
        return try PL.parseOneOf(
            parseIDParamsList_nil,
            parseIDParamsList_empty,
            parseIDParamsList_some,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseIdleDone(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try PL.parseFixedString("DONE", buffer: &buffer, tracker: tracker)
        try PL.parseNewline(buffer: &buffer, tracker: tracker)
    }

    func parseIPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IPartial {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            return try parseIPartialOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseIPartialOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IPartial {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try PL.parseFixedString(";PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLMessageSection {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLMessageSection in
            try PL.parseFixedString("/;SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSectionOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLMessageSection {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLMessageSection in
            try PL.parseFixedString(";SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPServer(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPServer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPServer in
            let info = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UserAuthenticationMechanism in
                let info = try self.parseUserAuthenticationMechanism(buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("@", buffer: &buffer, tracker: tracker)
                return info
            })
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
                return try self.parseNumber(buffer: &buffer, tracker: tracker)
            })
            return .init(userAuthenticationMechanism: info, host: host, port: port)
        }
    }

    func parseHost(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_ipv6(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_future(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseHost_literal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try PL.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let address = try PL.parseOneOf(
                parseHost_ipv6,
                parseHost_future,
                buffer: &buffer,
                tracker: tracker
            )
            try PL.parseFixedString("]", buffer: &buffer, tracker: tracker)
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

            let hostName = try ParserLibrary.parseBufferAsUTF8(newBuffer)
            return hostName
        }

        // TODO: This isn't great, but it is functional. Perhaps make it actually enforce IPv4 rules
        func parseHost_ipv4(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            let num3 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            let num4 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return "\(num1).\(num2).\(num3).\(num4)"
        }

        return try PL.parseOneOf(
            parseHost_literal,
            parseHost_regularName,
            parseHost_ipv4,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseEncodedMailboxUIDValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxUIDValidity {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxUIDValidity in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UIDValidity in
                try PL.parseFixedString(";UIDVALIDITY=", buffer: &buffer, tracker: tracker)
                return try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            })
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    func parseEncodedSearchQuery(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSearchQuery {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSearchQuery in
            let mailboxRef = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let query = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> EncodedSearch in
                try PL.parseFixedString("?", buffer: &buffer, tracker: tracker)
                return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
            })
            return .init(mailboxUIDValidity: mailboxRef, encodedSearch: query)
        }
    }

    func parseIMAPURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURL {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPURL in
            try PL.parseFixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            let command = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseURLCommand)
            return .init(server: server, query: command)
        }
    }

    func parseRelativeIMAPURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
        func parseRelativeIMAPURL_absolute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .absolutePath(try self.parseAbsoluteMessagePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_network(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .networkPath(try self.parseNetworkPath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .empty
        }

        return try PL.parseOneOf([
            parseRelativeIMAPURL_network,
            parseRelativeIMAPURL_absolute,
            parseRelativeIMAPURL_empty,
        ], buffer: &buffer, tracker: tracker)
    }

    func parseMessagePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessagePath {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessagePath in
            var ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)

            var uid = IUID(uid: 1)
            if ref.uidValidity == nil, ref.encodedMailbox.mailbox.last == Character(.init(UInt8(ascii: "/"))) {
                try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    ref.encodedMailbox.mailbox = String(ref.encodedMailbox.mailbox.dropLast())

                    uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
                }
            } else {
                uid = try self.parseIUID(buffer: &buffer, tracker: tracker)
            }

            var section = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIMAPURLSection)
            var partial: IPartial?
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    section!.encodedSection.section = String(section!.encodedSection.section.dropLast())

                    partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                }
            } else {
                partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIPartial)
            }
            return .init(mailboxReference: ref, iUID: uid, section: section, range: partial)
        }
    }

    func parseURLFetchType(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
        func parseURLFetchType_partialOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            let partial = try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseURLFetchType_sectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            var section = try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
            if section.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section.encodedSection.section = String(section.encodedSection.section.dropLast())
                do {
                    let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .sectionPartial(section: section, partial: partial)
                } catch is ParserError {
                    section.encodedSection.section.append("/")
                    return .sectionPartial(section: section, partial: nil)
                }
            }
            let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .sectionPartial(section: section, partial: partial)
        }

        func parseURLFetchType_uidSectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> URLMessageSection in
                try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .uidSectionPartial(uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .uidSectionPartial(uid: uid, section: section, partial: nil)
                }
            }
            let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseURLFetchType_refUidSectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            let ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> URLMessageSection in
                try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: nil)
                }
            }
            let partial = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartial in
                try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        return try PL.parseOneOf([
            parseURLFetchType_refUidSectionPartial,
            parseURLFetchType_uidSectionPartial,
            parseURLFetchType_sectionPartial,
            parseURLFetchType_partialOnly,
        ], buffer: &buffer, tracker: tracker)
    }

    func parseUChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try PL.parseByte(buffer: &buffer, tracker: tracker)
            guard num.isUnreserved else {
                throw ParserError(hint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try PL.parseByte(buffer: &buffer, tracker: tracker)
            guard num.isSubDelimsSh else {
                throw ParserError(hint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            // FIXME: Better parser for this
            try PL.parseFixedString("%", buffer: &buffer, tracker: tracker)
            var h1 = try PL.parseByte(buffer: &buffer, tracker: tracker)
            var h2 = try PL.parseByte(buffer: &buffer, tracker: tracker)

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

        return try PL.parseOneOf(
            parseUChar_unreserved,
            parseUChar_subDelimsSH,
            parseUChar_pctEncoded,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseAChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseAChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try PL.parseByte(buffer: &buffer, tracker: tracker)
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw ParserError(hint: "Expect achar, got \(char)")
            }
        }

        return try PL.parseOneOf(
            parseUChar,
            parseAChar_other,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseBChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseBChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try PL.parseByte(buffer: &buffer, tracker: tracker)
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw ParserError(hint: "Expect bchar, got \(char)")
            }
        }

        return try PL.parseOneOf(
            parseAChar,
            parseBChar_other,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseIUID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("/", buffer: &buffer, tracker: tracker)
            return try parseIUIDOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseIUIDOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString(";UID=", buffer: &buffer, tracker: tracker)
            return IUID(uid: try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURL {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthenticatedURL in
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseAuthenticatedURLVerifier(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: rump, verifier: verifier)
        }
    }

    func parseURLRumpMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpURLAndMechanism {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> RumpURLAndMechanism in
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    func parseURLFetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchData {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLFetchData in
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let data = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(url: url, data: data)
        }
    }

    func parseAuthenticatedURLRump(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURLRump {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthenticatedURLRump in
            let expiry = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseExpire)
            try PL.parseFixedString(";URLAUTH=", buffer: &buffer, tracker: tracker)
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    func parseAuthenticatedURLVerifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURLVerifier {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthenticatedURLVerifier in
            try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(urlAuthMechanism: authMechanism, encodedAuthenticationURL: urlAuth)
        }
    }

    func parseUserAuthenticationMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UserAuthenticationMechanism {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UserAuthenticationMechanism in
            let encodedUser = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseEncodedUser)
            let authenticationMechanism = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseIMAPURLAuthenticationMechanism)
            guard (encodedUser != nil || authenticationMechanism != nil) else {
                throw ParserError(hint: "Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, authenticationMechanism: authenticationMechanism)
        }
    }

    func parseFullDateTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDateTime {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("T", buffer: &buffer, tracker: tracker)
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    func parseFullDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDate {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    func parseFullTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        })
        return .init(hour: hour, minute: minute, second: second, fraction: fraction)
    }

    // Couldn't use `self` in a default parameter.
    func parseLiteralSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseLiteralSize(buffer: &buffer, tracker: tracker, maxLength: self.literalSizeLimit)
    }

    func parseLiteralSize(buffer: inout ParseBuffer, tracker: StackTracker, maxLength: Int) throws -> Int {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker, maxLength: maxLength)
            try PL.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    func parseLiteral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try PL.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            let bytes = try PL.parseBytes(buffer: &buffer, tracker: tracker, length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    func parseLiteral8(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try PL.parseFixedString("~{", buffer: &buffer, tracker: tracker)
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            let bytes = try PL.parseBytes(buffer: &buffer, tracker: tracker, length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

    // Couldn't use `self` in a default parameter.
    /// Parses *only* the literal size from the header, and ensures that the parsed size
    /// is within the allowed limit.
    func parseLiteralLength(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseLiteralLength(buffer: &buffer, tracker: tracker, maxLength: self.literalSizeLimit)
    }

    /// Parses *only* the literal size from the header, and ensures that the parsed size
    /// is within the allowed limit.
    func parseLiteralLength(buffer: inout ParseBuffer, tracker: StackTracker, maxLength: Int) throws -> Int {
        let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard length <= maxLength else {
            throw ExceededLiteralSizeLimitError()
        }
        return length
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    func parseMediaBasic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Kind_defined(_ option: String, result: Media.BasicKind, buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
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
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(try ParserLibrary.parseBufferAsUTF8(parsed))
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try PL.parseOneOf([
                parseMediaBasic_Kind_application,
                parseMediaBasic_Kind_audio,
                parseMediaBasic_Kind_image,
                parseMediaBasic_Kind_message,
                parseMediaBasic_Kind_video,
                parseMediaBasic_Kind_other,
            ], buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(kind: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    func parseMediaMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Message {
            try PL.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try PL.parseFixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try parseMediaMessage_rfc(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    func parseMediaSubtype(buffer: inout ParseBuffer, tracker: StackTracker) throws -> BodyStructure.MediaSubtype {
        let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
        return .init(try ParserLibrary.parseBufferAsUTF8(parsed))
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    func parseMediaText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try PL.parseFixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseBufferAsUTF8(parsed)
        }
    }

    func parseMetadataOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
        func parseMetadataOption_maxSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            try PL.parseFixedString("MAXSIZE ", buffer: &buffer, tracker: tracker)
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseMetadataOption_maxSize,
            parseMetadataOption_scope,
            parseMetadataOption_param,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseMetadataOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataOption] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
            })
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    func parseMetadataResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
        func parseMetadataResponse_values(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try PL.parseFixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try PL.parseFixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try PL.parseOneOf(
            parseMetadataResponse_values,
            parseMetadataResponse_list,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseMetadataValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
        func parseMetadataValue_nstring(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataValue_literal8(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(try self.parseLiteral8(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseMetadataValue_nstring,
            parseMetadataValue_literal8,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseMechanismBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MechanismBase64 {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MechanismBase64 in
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try PL.parseOptional(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
                try PL.parseFixedString("=", buffer: &buffer, tracker: tracker)
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    func parseGmailLabel(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
        func parseGmailLabel_backslash(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            try PL.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(ByteBuffer(string: "\\\(att)"))
        }

        func parseGmailLabel_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(raw)
        }

        return try PL.parseOneOf(
            parseGmailLabel_backslash,
            parseGmailLabel_string,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    func parseNamespace(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try PL.parseOneOf(
            parseNamespace_nil,
            parseNamespace_some,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    func parseNamespaceDescription(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Character? {
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let char = try PL.parseByte(buffer: &buffer, tracker: tracker)
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let char = try PL.parseOneOf(
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
                buffer: &buffer,
                tracker: tracker
            )
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .init(string: string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    func parseNamespaceResponseExtensions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<ByteBuffer, [ByteBuffer]> {
        var kvs = OrderedDictionary<ByteBuffer, [ByteBuffer]>()
        try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
        return kvs
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    func parseNamespaceResponseExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<ByteBuffer, [ByteBuffer]> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .init(key: s1, value: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    func parseNamespaceResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try PL.parseFixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    func parseNil(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try PL.parseFixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    func parseNString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try PL.parseFixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try PL.parseOneOf(
            parseNString_nil,
            parseNString_some,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // number          = 1*DIGIT
    func parseNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try PL.parseUnsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    func parseNZNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try PL.parseUnsignedInteger(buffer: &buffer, tracker: tracker).number
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    func parseOptionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<OptionExtensionKind, OptionValueComp?> {
        func parseOptionExtensionKind_standard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .standard(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionKind_vendor(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<OptionExtensionKind, OptionValueComp?> in
            let type = try PL.parseOneOf(
                parseOptionExtensionKind_standard,
                parseOptionExtensionKind_vendor,
                buffer: &buffer,
                tracker: tracker
            )
            let value = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    func parseOptionValueComp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try PL.parseOneOf(
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // option-value =  "(" option-val-comp ")"
    func parseOptionValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    func parseOptionVendorTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, String> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, String> in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(key: token, value: atom)
        }
    }

    // partial         = "<" number "." nz-number ">"
    func parsePartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ClosedRange<UInt32> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
            try PL.parseFixedString("<", buffer: &buffer, tracker: tracker)
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try PL.parseFixedString(">", buffer: &buffer, tracker: tracker)
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return num1 ... upper2.partialValue
        }
    }

    func parsePartialRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PartialRange {
        func parsePartialRange_length(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
            try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> PartialRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parsePartialRange_length)
            return .init(offset: offset, length: length)
        }
    }

    // password        = astring
    func parsePassword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    func parsePatterns(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    func parseQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try PL.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    func parseReturnOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try PL.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try PL.parseFixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    func parseScopeOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
        func parseScopeOption_zero(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try PL.parseFixedString("0", buffer: &buffer, tracker: tracker)
            return .zero
        }

        func parseScopeOption_one(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try PL.parseFixedString("1", buffer: &buffer, tracker: tracker)
            return .one
        }

        func parseScopeOption_infinity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try PL.parseFixedString("infinity", buffer: &buffer, tracker: tracker)
            return .infinity
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("DEPTH ", buffer: &buffer, tracker: tracker)
            return try PL.parseOneOf(
                parseScopeOption_zero,
                parseScopeOption_one,
                parseScopeOption_infinity,
                buffer: &buffer,
                tracker: tracker
            )
        }
    }

    // section         = "[" [section-spec] "]"
    func parseSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSection_none(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier in
                try PL.parseFixedString("[]", buffer: &buffer, tracker: tracker)
                return .complete
            }
        }

        func parseSection_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try PL.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }

        return try PL.parseOneOf(
            parseSection_none,
            parseSection_some,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // section-binary  = "[" [section-part] "]"
    func parseSectionBinary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try PL.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let part = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSectionPart)
            try PL.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return part ?? .init([])
        }
    }

    // section-part    = nz-number *("." nz-number)
    func parseSectionPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    func parseSectionSpecifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            return .init(kind: kind)
        }

        func parseSectionSpecifier_withPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                try PL.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try PL.parseOneOf(
            parseSectionSpecifier_withPart,
            parseSectionSpecifier_noPart,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // section-text    = section-msgtext / "MIME"
    func parseSectionSpecifierKind(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try PL.parseFixedString("MIME", buffer: &buffer, tracker: tracker)
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try PL.parseFixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionSpecifierKind_headerFields(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try PL.parseFixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try PL.parseFixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try PL.parseFixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        func parseSectionSpecifierKind_complete(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try PL.parseOneOf([
            parseSectionSpecifierKind_mime,
            parseSectionSpecifierKind_headerFields,
            parseSectionSpecifierKind_notHeaderFields,
            parseSectionSpecifierKind_header,
            parseSectionSpecifierKind_text,
            parseSectionSpecifierKind_complete,
        ], buffer: &buffer, tracker: tracker)
    }

    func parseSelectParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
        func parseSelectParameter_basic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try PL.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
            return .condStore
        }

        func parseSelectParameter_qresync(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try PL.parseFixedString("QRESYNC (", buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUIDs = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> UIDSet in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            })
            let seqMatchData = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceMatchData in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseSequenceMatchData(buffer: &buffer, tracker: tracker)
            })
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .qresync(.init(uidValidity: uidValidity, modificationSequenceValue: modSeqVal, knownUIDs: knownUIDs, sequenceMatchData: seqMatchData))
        }

        return try PL.parseOneOf(
            parseSelectParameter_qresync,
            parseSelectParameter_condstore,
            parseSelectParameter_basic,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    func parseParameters(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, ParameterValue?> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OrderedDictionary<String, ParameterValue?> in
            try PL.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var kvs = OrderedDictionary<String, ParameterValue?>()
            let param = try self.parseParameter(buffer: &buffer, tracker: tracker)
            kvs[param.key] = param.value
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> KeyValue<String, ParameterValue?> in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return kvs
        }
    }

    func parseSortData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SortData? {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SortData? in
            try PL.parseFixedString("SORT", buffer: &buffer, tracker: tracker)
            let _components = try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ([Int], ModificationSequenceValue) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
                try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                })
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
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
    func parseStatusAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        let string = try ParserLibrary.parseBufferAsUTF8(parsed)
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    func parseStatusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try PL.parseFixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    func parseStoreModifiers(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [StoreModifier] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
            })
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    func parseStoreModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
        func parseFetchModifier_unchangedSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseFetchModifier_unchangedSince,
            parseFetchModifier_other,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseStoreOperation(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreOperation {
        try PL.parseOneOf(
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
                return .add
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
                return .remove
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try PL.parseFixedString("", buffer: &buffer, tracker: tracker)
                return .replace
            },
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseStoreSilent(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Bool {
        do {
            try PL.parseFixedString(".SILENT", buffer: &buffer, tracker: tracker)
            return true
        } catch is ParserError {
            return false
        }
    }

    func parseStoreGmailLabels(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreGmailLabels {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("X-GM-LABELS", allowLeadingSpaces: false, buffer: &buffer, tracker: tracker)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var labels = [try self.parseGmailLabel(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &labels, tracker: tracker) { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseGmailLabel(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .init(operation: operation, silent: silent, gmailLabels: labels)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    func parseStoreFlags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreFlags_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
            var flags = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &flags, tracker: tracker) { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseFlag(buffer: &buffer, tracker: tracker)
            }
            return flags
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> StoreFlags in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("FLAGS", allowLeadingSpaces: false, buffer: &buffer, tracker: tracker)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let flags = try PL.parseOneOf([
                self.parseFlagList,
                parseStoreFlags_array,
            ], buffer: &buffer, tracker: tracker)
            return .init(operation: operation, silent: silent, flags: flags)
        }
    }

    func parseStoreData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreData {
        try PL.parseOneOf(
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreData in
                let data = try self.parseStoreGmailLabels(buffer: &buffer, tracker: tracker)
                return .gmailLabels(data)
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreData in
                let data = try self.parseStoreFlags(buffer: &buffer, tracker: tracker)
                return .flags(data)
            },
            buffer: &buffer,
            tracker: tracker
        )
    }

    // string          = quoted / literal
    func parseString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.parseOneOf(
            self.parseQuoted,
            self.parseLiteral,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    func parseTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAStringChar && char != UInt8(ascii: "+")
        }
        return try ParserLibrary.parseBufferAsUTF8(parsed)
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    func parseTaggedExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let key = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if key.lowercased() == "catenate" {
                throw ParserError(hint: "catenate extension")
            }

            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    func parseParameterName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            let fchar = try PL.parseByte(buffer: &buffer, tracker: tracker)
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let parsed = try PL.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isTaggedLabelChar
            }
            let trailing = try ParserLibrary.parseBufferAsUTF8(parsed)
            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    func parseTaggedExtensionComplex_continuation(
        into: inout [String],
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws {
        while true {
            do {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                return
            }
        }
    }

    func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws {
            let parsed = try self.parseAString(buffer: &buffer, tracker: tracker)
            into.append(try ParserLibrary.parseBufferAsUTF8(parsed))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws {
            try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
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
    func parseTaggedExtensionComplex(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    func parseParameterValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
        func parseTaggedExtensionSimple_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
            .sequence(try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try PL.parseOneOf(
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionVal_comp,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // text            = 1*TEXT-CHAR
    func parseText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    func parseUAuthMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLAuthenticationMechanism {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker, where: { char in
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
        return URLAuthenticationMechanism(try ParserLibrary.parseBufferAsUTF8(parsed))
    }

    // userid          = astring
    func parseUserId(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var astring = try self.parseAString(buffer: &buffer, tracker: tracker)
        return astring.readString(length: astring.readableBytes)! // if this fails, something has gone very, very wrong
    }

    // vendor-token     = atom (maybe?!?!?!)
    func parseVendorToken(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAlpha
        }
        return try ParserLibrary.parseBufferAsUTF8(parsed)
    }

    // setquota_list   ::= "(" 0#setquota_resource ")"
    func parseQuotaLimits(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [QuotaLimit] {
        // setquota_resource ::= atom SP number
        func parseQuotaLimit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaLimit {
            try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces)
                let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaLimit(resourceName: resourceName, limit: limit)
            }
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) throws -> [QuotaLimit] in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let limits = try PL.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: parseQuotaLimit)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return limits
        }
    }

    func parseQuotaRoot(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaRoot {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return QuotaRoot(string)
    }

    // RFC 5465
    // one-or-more-mailbox = mailbox / many-mailboxes
    func parseOneOrMoreMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
        // many-mailboxes  = "(" mailbox *(SP mailbox) ")
        func parseManyMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces) != nil {
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
            }
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
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

        return try PL.parseOneOf(
            parseManyMailboxes,
            parseSingleMailboxes,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    func parseFilterMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("selected", buffer: &buffer, tracker: tracker)
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("selected-delayed", buffer: &buffer, tracker: tracker)
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("inboxes", buffer: &buffer, tracker: tracker)
            return .inboxes
        }

        func parseFilterMailboxes_Personal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("personal", buffer: &buffer, tracker: tracker)
            return .personal
        }

        func parseFilterMailboxes_Subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("subscribed", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("subtree ", buffer: &buffer, tracker: tracker)
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("mailboxes ", buffer: &buffer, tracker: tracker)
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 7377
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try PL.parseFixedString("subtree-one ", buffer: &buffer, tracker: tracker)
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf([
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

    // RFC 7377
    // scope-options =  scope-option *(SP scope-option)
    func parseExtendedSearchScopeOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtendedSearchScopeOptions {
        var options = OrderedDictionary<String, ParameterValue?>()
        repeat {
            let param = try parseParameter(buffer: &buffer, tracker: tracker)
            options[param.key] = param.value
        } while try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces) != nil
        if let returnValue = ExtendedSearchScopeOptions(options) {
            return returnValue
        } else {
            throw ParserError(hint: "Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
    }

    // RFC 7377
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    func parseExtendedSearchSourceOptions(buffer: inout ParseBuffer,
                                          tracker: StackTracker) throws -> ExtendedSearchSourceOptions
    {
        func parseExtendedSearchSourceOptions_spaceFilter(buffer: inout ParseBuffer,
                                                          tracker: StackTracker) throws -> MailboxFilter
        {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseExtendedSearchSourceOptions_sourceMBox(buffer: inout ParseBuffer,
                                                         tracker: StackTracker) throws -> [MailboxFilter]
        {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            while let anotherSource = try PL.parseOptional(buffer: &buffer,
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
            try PL.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            let result = try parseExtendedSearchScopeOptions(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try PL.parseFixedString("IN (", buffer: &buffer, tracker: tracker)
            let sourceMbox = try parseExtendedSearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try PL.parseOptional(buffer: &buffer,
                                                    tracker: tracker,
                                                    parser: parseExtendedSearchSourceOptions_scopeOptions)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            if let result = ExtendedSearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) {
                return result
            } else {
                throw ParserError(hint: "Failed to construct esearch source options")
            }
        }
    }

    // RFC 7377
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    // Ignoring the command here.
    func parseExtendedSearchOptions(buffer: inout ParseBuffer,
                                    tracker: StackTracker) throws -> ExtendedSearchOptions
    {
        func parseExtendedSearchOptions_sourceOptions(buffer: inout ParseBuffer,
                                                      tracker: StackTracker) throws -> ExtendedSearchSourceOptions
        {
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let result = try parseExtendedSearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try PL.parseOptional(buffer: &buffer,
                                                 tracker: tracker,
                                                 parser: parseExtendedSearchOptions_sourceOptions)
        let returnOpts = try PL.parseOptional(buffer: &buffer,
                                              tracker: tracker,
                                              parser: self.parseSearchReturnOptions) ?? []
        try PL.parseSpaces(buffer: &buffer, tracker: tracker)
        let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
        return ExtendedSearchOptions(key: program, charset: charset, returnOptions: returnOpts, sourceOptions: sourceOptions)
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    func parse2Digit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    func parse4Digit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    func parseNDigits(buffer: inout ParseBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let (num, size) = try PL.parseUnsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
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
