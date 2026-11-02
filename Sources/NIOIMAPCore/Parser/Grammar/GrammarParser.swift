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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

/// Parsing a literal exceeded the maximum configured size limit.
///
/// IMAP protocol literals (data between `{size}` markers) can be arbitrarily large.
/// To prevent memory exhaustion from malformed or malicious input, a maximum literal
/// size is enforced. If a literal exceeds this limit, this error is thrown.
///
/// A DoS protection mechanism.
///
/// - SeeAlso: [RFC 3501 Section 4.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3.3),
///   ``ExceededMaximumBodySizeError``
public struct ExceededLiteralSizeLimitError: Error {
    /// The actual size of the literal.
    public var actualCount: Int

    /// The configured maximum literal size.
    public var maximumCount: Int

    /// Creates a new error with the actual and maximum sizes.
    ///
    /// - Parameters:
    ///   - actualCount: The size of the literal that exceeded the limit
    ///   - maximumCount: The configured maximum size
    public init(actualCount: Int, maximumCount: Int) {
        self.actualCount = actualCount
        self.maximumCount = maximumCount
    }
}

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

//
// Note: The `parsedStringCache` is not (necessarily) sendable. We should fix this.
//
struct GrammarParser: @unchecked Sendable {
    static let defaultParsedStringCache: @Sendable (String) -> String = { str in
        str
    }

    var parsedStringCache: (String) -> String

    let literalSizeLimit: Int
    let messageBodySizeLimit: Int

    /// Creates a new grammar parser with configurable limits.
    ///
    /// - Parameters:
    ///   - literalSizeLimit: Maximum size of a single literal. Defaults to ``IMAPDefaults/literalSizeLimit``.
    ///   - messageBodySizeLimit: Maximum size of a message body. Defaults to ``IMAPDefaults/bodySizeLimit``.
    ///   - parsedStringCache: Optional string caching function for memory optimization. When provided,
    ///     every parsed string is passed through this function, which can return a cached version
    ///     to reduce memory usage for responses with repeated strings. Defaults to `nil`.
    init(
        literalSizeLimit: Int = IMAPDefaults.literalSizeLimit,
        messageBodySizeLimit: Int = IMAPDefaults.bodySizeLimit,
        parsedStringCache: ((String) -> String)? = nil
    ) {
        self.literalSizeLimit = literalSizeLimit
        self.messageBodySizeLimit = messageBodySizeLimit
        self.parsedStringCache = parsedStringCache ?? Self.defaultParsedStringCache
    }
}

typealias PL = ParserLibrary

// MARK: - Grammar Parsers

extension GrammarParser {
    /// Consumes the keyword that selects a sub-parser, and returns it uppercased.
    ///
    /// The keyword is the leading unbroken run of alphanumerics, `.` and `-`; `LOGIN` out of
    /// `LOGIN username password`, `RFC822.SIZE` out of `RFC822.SIZE 1234`. IMAP keywords are
    /// case-insensitive, hence the uppercasing, and every call site compares against upper-case
    /// literals.
    ///
    /// Consumes the keyword whether or not the caller goes on to recognise it, so a caller that may
    /// reject it has to save and restore the cursor around the whole selection. That is what
    /// ``selectingKeyword(buffer:_:)`` is for.
    ///
    /// - Throws: `IncompleteMessage` when every byte that has arrived is part of the keyword, since
    ///     more could still follow; ``ParserError`` when the first byte cannot start one.
    func parseLookupKeyword(buffer: inout ParseBuffer) throws -> String {
        // A flat scan with nothing to recurse into, so it gets a throwaway tracker rather than
        // taking the caller's.
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            switch char {
            case _ where char.isAlphaNum, UInt8(ascii: "."), UInt8(ascii: "-"):
                return true
            default:
                return false
            }
        }
        return try decodeUTF8(parsed).uppercased()
    }

    /// Parses a keyword with ``parseLookupKeyword(buffer:)``, hands it to `select`, and rewinds the
    /// cursor if anything throws.
    ///
    /// Pair it with a `switch` on the keyword, not a dictionary of sub-parsers. A dictionary literal is
    /// built **on every call**, and every entry that names a nested function or a method captures the
    /// `GrammarParser`, so each one is a separate heap-allocated closure context, of which exactly one
    /// is ever invoked. A `switch` calls the chosen sub-parser directly, so no closure is ever formed.
    ///
    /// - Important: `select` should throw ``ParserError`` for an unrecognised keyword — not
    ///     `IncompleteMessage`, which would make the caller wait for bytes that cannot help. Callers
    ///     that fall back to another production (`parseFetchAttribute`, say) catch exactly that.
    func selectingKeyword<T>(
        buffer: inout ParseBuffer,
        _ select: (String, inout ParseBuffer) throws -> T
    ) throws -> T {
        let save = buffer
        do {
            let keyword = try parseLookupKeyword(buffer: &buffer)
            return try select(keyword, &buffer)
        } catch {
            buffer = save
            throw error
        }
    }

    // astring         = 1*ASTRING-CHAR / string
    func parseAString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try buffer.parseOneOrMoreCharacters { char -> Bool in
                char.isAStringChar
            }
        }
        return try buffer.parseOneOf(
            self.parseString,
            { try parseOneOrMoreASTRINGCHAR(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // atom            = 1*ATOM-CHAR
    func parseAtom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar
        }
        let string = try decodeUTF8(parsed)
        return self.parsedStringCache(string)
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    func parseAttributeFlag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
        func parseAttributeFlag_slashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            try buffer.matchFixed("\\\\")
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: atom)
        }

        return try buffer.parseOneOf(
            { try parseAttributeFlag_slashed(buffer: &$0, tracker: $1) },
            { try parseAttributeFlag_unslashed(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    /// RFC 3501 defines
    /// ```
    /// auth-type = atom
    /// ```
    /// but [RFC 4422 section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1)
    /// restricts what a mechanism name may contain. ``AuthenticationMechanism/init(_:)`` enforces
    /// that, and a name it rejects is a parse error.
    func parseAuthenticationMechanism(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> AuthenticationMechanism {
        let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
        guard let mechanism = AuthenticationMechanism(atom) else {
            throw ParserError(hint: "Invalid authentication mechanism name: \(atom)")
        }
        return mechanism
    }

    func parseAuthenticatedURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NetworkMessagePath {
        try buffer.composite(tracker: tracker) { buffer, tracker -> NetworkMessagePath in
            try buffer.matchFixed("imap://")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let messagePath = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePath: messagePath)
        }
    }

    func parseAuthIMAPURLFull(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> FullAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(networkMessagePath: imapURL, authenticatedURL: urlAuth)
        }
    }

    func parseAuthIMAPURLRump(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> RumpAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: imapURL, authenticatedURLRump: rump)
        }
    }

    func parseInitialResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
        func parseInitialResponse_empty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
            try buffer.matchFixed("=")
            return .empty
        }

        func parseInitialResponse_data(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InitialResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .init(base64)
        }

        return try buffer.parseOneOf(
            { try parseInitialResponse_empty(buffer: &$0, tracker: $1) },
            { try parseInitialResponse_data(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // base64          = *(4base64-char) [base64-terminal]
    func parseBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try buffer.parseZeroOrMoreCharacters {
                $0.isBase64Char || $0 == UInt8(ascii: "=")
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
    func parseCapability(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(unchecked: string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    func parseCapabilityData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try buffer.composite(tracker: tracker) { buffer, tracker -> [Capability] in
            try buffer.matchFixed("CAPABILITY")
            return try self.parseCapabilitySuffix(buffer: &buffer, tracker: tracker)
        }
    }

    // *(SP capability)
    func parseCapabilitySuffix(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try buffer.parseOneOrMore(tracker: tracker) { (buffer, tracker) in
            try buffer.parseSpaces()
            return try self.parseCapability(buffer: &buffer, tracker: tracker)
        }
    }

    // charset          = atom / quoted
    func parseCharset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CharacterSetName {
        func parseCharset_atom(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CharacterSetName {
            CharacterSetName(unchecked: try parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseCharset_quoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CharacterSetName {
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            // `parseQuoted` is lenient (CR, LF, 8-bit, empty); reject what can't be written back.
            guard let name = CharacterSetName(string) else {
                throw ParserError(hint: "Invalid charset \(String(reflecting: string))")
            }
            return name
        }

        return try buffer.parseOneOf(
            { try parseCharset_atom(buffer: &$0, tracker: $1) },
            { try parseCharset_quoted(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseChangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ChangedSinceModifier {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> ChangedSinceModifier in
            try buffer.matchFixed("CHANGEDSINCE ")
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    func parseUnchangedSinceModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UnchangedSinceModifier
    {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> UnchangedSinceModifier in
            try buffer.matchFixed("UNCHANGEDSINCE ")
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    func parseChildinfoExtendedItem(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try buffer.composite(tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try buffer.matchFixed("CHILDINFO (")
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) -> ListSelectBaseOption in
                try buffer.parseSpaces()
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    // condstore-param = "CONDSTORE"
    func parseConditionalStoreParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try buffer.matchFixed("CONDSTORE")
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    func parseContinuationRequest(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ContinuationRequest {
        func parseContinuationRequest_base64(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ContinuationRequest {
            try buffer.parseSpaces()
            let base64 = try self.parseBase64(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()

            guard base64.readableBytes > 0 else {
                throw ParserError()
            }

            return .data(base64)
        }

        func parseContinuationRequest_responseText(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ContinuationRequest {
            try buffer.parseSpaces()
            let responseText = try self.parseResponseText(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            return .responseText(responseText)
        }

        // Allow no space and no additional text after "+":
        func parseContinuationRequest_empty(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ContinuationRequest {
            try buffer.matchNewline()
            return .responseText(ResponseText(code: nil, text: ""))
        }

        try buffer.matchFixed("+")
        return try buffer.parseOneOf(
            [
                { try parseContinuationRequest_base64(buffer: &$0, tracker: $1) },
                { try parseContinuationRequest_responseText(buffer: &$0, tracker: $1) },
                { try parseContinuationRequest_empty(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // create-param = create-param-name [SP create-param-value]
    func parseCreateParameters(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed(" (")
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseCreateParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter {
        func parseCreateParameter_parameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter
        {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CreateParameter
        {
            try buffer.matchFixed("USE (")
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) in
                try buffer.parseSpaces()
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .attributes(array)
        }

        return try buffer.parseOneOf(
            { try parseCreateParameter_specialUse(buffer: &$0, tracker: $1) },
            { try parseCreateParameter_parameter(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseParameter<Kind>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<ExtensionKey<Kind>, ParameterValue?> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let name: ExtensionKey<Kind> = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try buffer.parseSpaces()
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: value)
        }
    }

    func parseUseAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
        func parseUseAttribute_fixed(
            expected: String,
            returning: UseAttribute,
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> UseAttribute {
            try buffer.matchFixed(expected)
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

        func parseUseAttribute_snoozed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Snoozed", returning: .snoozed, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_scheduled(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(
                expected: "\\Scheduled",
                returning: .scheduled,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseUseAttribute_memos(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Memos", returning: .memos, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UseAttribute {
            try buffer.matchFixed("\\")
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\\" + att)
        }

        return try buffer.parseOneOf(
            [
                { try parseUseAttribute_all(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_archive(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_drafts(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_flagged(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_junk(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_sent(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_trash(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_snoozed(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_scheduled(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_memos(buffer: &$0, tracker: $1) },
                { try parseUseAttribute_other(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseEncodedAuthenticationType(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> EncodedAuthenticationType {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedAuthenticationType in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseAChar).reduce([], +)
            let string = String(decoding: array, as: Unicode.UTF8.self)
            guard string != EncodedAuthenticationType.anyMechanism else {
                throw ParserError(hint: "`*` is any mechanism, not an enc-auth-type")
            }
            return .init(unchecked: string)
        }
    }

    func parseEncodedMailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedMailbox {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedMailbox in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSearch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSearch {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedSearch in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSection {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedSection in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedUser {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedUser in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedAuthenticatedURL in
            // `32*HEXDIG`
            let bytes = try buffer.parseOneOrMoreCharacters(where: \.isHexCharacter)
            guard bytes.readableBytes >= EncodedAuthenticatedURL.minimumLength else {
                throw ParserError(hint: "Expected at least 32 hex digits, got \(String(buffer: bytes))")
            }
            return .init(unchecked: String(buffer: bytes))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    func parseEnableData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Capability] {
        try buffer.composite(tracker: tracker) { buffer, tracker -> [Capability] in
            try buffer.matchFixed("ENABLED")
            return try buffer.parseZeroOrMore(tracker: tracker) { (buffer, tracker) -> Capability in
                try buffer.parseSpaces()
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)

    func parseExtendedSearchResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtendedSearchResponse
    {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let correlator = try buffer.parseOptional(tracker: tracker, parser: self.parseSearchCorrelator)
            let kind: ExtendedSearchResponse.Kind =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                    try buffer.matchFixed(" UID")
                    return .uid
                } ?? .sequenceNumber
            let searchReturnData = try buffer.parseZeroOrMore(tracker: tracker) {
                (buffer, tracker) -> SearchReturnData in
                try buffer.parseSpaces()
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ExtendedSearchResponse(correlator: correlator, kind: kind, returnData: searchReturnData)
        }
    }

    func parseExpire(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Expire {
        try buffer.composite(tracker: tracker) { buffer, tracker -> Expire in
            try buffer.matchFixed(";EXPIRE=")
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    func parseAccess(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
        func parseAccess_submit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try buffer.matchFixed("submit+")
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try buffer.matchFixed("user+")
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authenticatedUser(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try buffer.matchFixed("authuser")
            return .authenticateUser
        }

        func parseAccess_anonymous(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Access {
            try buffer.matchFixed("anonymous")
            return .anonymous
        }

        return try buffer.parseOneOf(
            [
                { try parseAccess_submit(buffer: &$0, tracker: $1) },
                { try parseAccess_user(buffer: &$0, tracker: $1) },
                { try parseAccess_authenticatedUser(buffer: &$0, tracker: $1) },
                { try parseAccess_anonymous(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    func parseFilterName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey.FilterName {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
        return SearchKey.FilterName(unchecked: try decodeUTF8(parsed))
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

        return try buffer.parseOneOf(
            [
                { try parseFlag_keyword(buffer: &$0, tracker: $1) },
                { try parseFlag_extension(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // flag-extension  = "\" atom
    func parseFlagExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        try buffer.composite(tracker: tracker) { buffer, tracker -> String in
            try buffer.matchFixed("\\")
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    /// RFC 3501 defines
    /// ```
    /// flag-keyword    = atom
    /// ```
    /// but Gmail sends flags with `[` and `]` in them.
    func parseFlagKeyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar || char.isResponseSpecial
        }
        let string = try self.parsedStringCache(decodeUTF8(parsed))
        return Flag.Keyword(unchecked: string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    func parseFlagList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("(")
            let flags =
                try buffer.parseOptional(tracker: tracker) { (buffer, _) -> [Flag] in
                    var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                    try buffer.parseZeroOrMore(into: &output, tracker: tracker) { buffer, tracker in
                        try buffer.matchFixed(" ")
                        return try self.parseFlag(buffer: &buffer, tracker: tracker)
                    }
                    return output
                } ?? []
            try buffer.matchFixed(")", leadingSpaces: .allowed)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    func

        parseFlagPerm(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag
    {
        func parseFlagPerm_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try buffer.matchFixed("\\*")
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseFlagPerm_wildcard(buffer: &$0, tracker: $1) },
            { try parseFlagPerm_flag(buffer: &$0, tracker: $1) },
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
        try buffer.composite(tracker: tracker) { buffer, tracker -> [String] in
            try buffer.matchFixed("(")
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try buffer.parseSpaces()
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return output
        }
    }

    // resp-jmapaccess = "JMAPACCESS" SP quoted
    func parseJMAPAccess(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponsePayload.JMAPAccessURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ResponsePayload.JMAPAccessURL in
            try buffer.matchFixed("JMAPACCESS")
            try buffer.parseSpaces()
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            guard let components = URLComponents(string: string) else {
                throw ParserError(hint: "Couldn't parse JMAPACCESS URL")
            }
            guard
                let url = components.url,
                let jmapAccessURL = ResponsePayload.JMAPAccessURL(url)
            else {
                throw ParserError(hint: "Invalid JMAPACCESS URL")
            }
            return jmapAccessURL
        }
    }

    func parseURLCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
        func parseURLCommand_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
            .messageList(try self.parseEncodedSearchQuery(buffer: &buffer, tracker: tracker))
        }

        func parseURLCommand_part(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLCommand {
            let path = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            let auth = try buffer.parseOptional(tracker: tracker, parser: self.parseIURLAuth)
            return .fetch(path: path, authenticatedURL: auth)
        }

        return try buffer.parseOneOf(
            { try parseURLCommand_part(buffer: &$0, tracker: $1) },
            { try parseURLCommand_list(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseNetworkPath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NetworkPath {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> NetworkPath in
            try buffer.matchFixed("//")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
            return .init(server: server, query: command)
        }
    }

    func parseLastCommandSet<T: MessageIdentifier>(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        setParser: LegacySubParser<MessageIdentifierSetNonEmpty<T>>
    ) throws -> LastCommandSet<T> {
        func parseLastCommandSet_lastCommand(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> LastCommandSet<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        func parseLastCommandSet_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            .set(try setParser(&buffer, tracker))
        }

        return try buffer.parseOneOf(
            { try parseLastCommandSet_lastCommand(buffer: &$0, tracker: $1) },
            { try parseLastCommandSet_set(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseLastCommandMessageID<T: MessageIdentifier>(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        setParser: LegacySubParser<T>
    ) throws -> LastCommandMessageID<T> {
        func parseLastCommandMessageID_lastCommand(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> LastCommandMessageID<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        func parseLastCommandMessageID_id(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> LastCommandMessageID<T> {
            .id(try setParser(&buffer, tracker))
        }

        return try buffer.parseOneOf(
            { try parseLastCommandMessageID_lastCommand(buffer: &$0, tracker: $1) },
            { try parseLastCommandMessageID_id(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseAbsoluteMessagePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AbsoluteMessagePath {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> AbsoluteMessagePath in
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
            return .init(command: command)
        }
    }

    func parseIMAPURLAuthenticationMechanism(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> IMAPURLAuthenticationMechanism {
        func parseIMAPURLAuthenticationMechanism_any(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> IMAPURLAuthenticationMechanism {
            try buffer.matchFixed("*")
            return .any
        }

        func parseIMAPURLAuthenticationMechanism_encoded(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> IMAPURLAuthenticationMechanism {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed(";AUTH=")
            // Longest match first: `;AUTH=*x` is the type `*x`, not any mechanism.
            return try buffer.parseOneOf(
                { try parseIMAPURLAuthenticationMechanism_encoded(buffer: &$0, tracker: $1) },
                { try parseIMAPURLAuthenticationMechanism_any(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }
    }

    // id-response = "ID" SP id-params-list
    func parseIDResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<String, String?>
    {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed("ID ")
            let result = try parseIDParamsList(buffer: &buffer, tracker: tracker)
            // datamail.in appends a `+` here for some reason.
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                try buffer.matchByte("+")
            }
            return result
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    func parseIDParamsList(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> OrderedDictionary<String, String?> {
        func parseIDValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String? {
            guard let value = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return nil
            }
            return try ModifiedUTF7.decode(value)
        }

        func parseIDParamsList_nil(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> OrderedDictionary<String, String?> {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (String, String?) {
            let parsedKey = try self.parseString(buffer: &buffer, tracker: tracker)
            let key = try decodeUTF8(parsedKey)
            try buffer.parseSpaces()
            return (key, try parseIDValue(buffer: &buffer, tracker: tracker))
        }

        func parseIDParamsList_empty(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> OrderedDictionary<String, String?> {
            try buffer.matchFixed("(")
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
            }
            try buffer.matchFixed(")")
            return [:]
        }

        func parseIDParamsList_some(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> OrderedDictionary<String, String?> {
            try buffer.matchFixed("(")
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
            }
            let (key, value) = try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            var dic: OrderedDictionary<String, String?> = [key: value]
            try buffer.parseZeroOrMore(into: &dic, tracker: tracker) {
                (buffer, tracker) -> (String, String?) in
                try buffer.parseSpaces()
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
            }
            try buffer.matchFixed(")")
            return dic
        }
        return try buffer.parseOneOf(
            { try parseIDParamsList_nil(buffer: &$0, tracker: $1) },
            { try parseIDParamsList_empty(buffer: &$0, tracker: $1) },
            { try parseIDParamsList_some(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseIdleDone(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try buffer.matchFixed("DONE")
        try buffer.matchNewline()
    }

    func parseMessagePathByteRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessagePath.ByteRange {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MessagePath.ByteRange in
            try buffer.matchFixed("/")
            return try parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseMessagePathByteRangeOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessagePath.ByteRange
    {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MessagePath.ByteRange in
            try buffer.matchFixed(";PARTIAL=")
            return .init(range: try self.parseByteRange(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLMessageSection {
        try buffer.composite(tracker: tracker) { buffer, tracker -> URLMessageSection in
            try buffer.matchFixed("/;SECTION=")
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSectionOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLMessageSection {
        try buffer.composite(tracker: tracker) { buffer, tracker -> URLMessageSection in
            try buffer.matchFixed(";SECTION=")
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPServer(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPServer {
        try buffer.composite(tracker: tracker) { buffer, tracker -> IMAPServer in
            let info = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> UserAuthenticationMechanism in
                    let info = try self.parseUserAuthenticationMechanism(buffer: &buffer, tracker: tracker)
                    try buffer.matchFixed("@")
                    return info
                }
            )
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> Int in
                    try buffer.matchFixed(":")
                    return try self.parseNumber(buffer: &buffer, tracker: tracker)
                }
            )
            guard let port else {
                return .init(userAuthenticationMechanism: info, host: host, port: nil)
            }
            guard let validPort = UInt16(exactly: port) else {
                throw ParserError(hint: "Port \(port) out of range")
            }
            return .init(userAuthenticationMechanism: info, host: host, port: validPort)
        }
    }

    /// Reads the longest run of `host` characters, then validates it as a whole: `[::1]`,
    /// `192.0.2.1`, `imap.example.com`.
    func parseHost(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPServer.Host {
        func parseHost_ipLiteral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            try buffer.matchFixed("[")
            let address = try buffer.parseOneOrMoreCharacters {
                $0.isUnreserved || $0.isSubDelims || $0 == UInt8(ascii: ":")
            }
            try buffer.matchFixed("]")
            return "[\(String(buffer: address))]"
        }

        func parseHost_registeredName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
            let name = try buffer.parseZeroOrMoreCharacters {
                URLCharacterClass.registeredName.contains($0) || $0 == UInt8(ascii: "%")
            }
            return String(buffer: name)
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            let string = try buffer.parseOneOf(
                { try parseHost_ipLiteral(buffer: &$0, tracker: $1) },
                { try parseHost_registeredName(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
            guard let host = IMAPServer.Host(string) else {
                throw ParserError(hint: "Invalid host \(string)")
            }
            return host
        }
    }

    func parseEncodedMailboxUIDValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxUIDValidity {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MailboxUIDValidity in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> UIDValidity in
                    try buffer.matchFixed(";UIDVALIDITY=")
                    return try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
                }
            )
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    func parseEncodedSearchQuery(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EncodedSearchQuery {
        try buffer.composite(tracker: tracker) { buffer, tracker -> EncodedSearchQuery in
            let mailboxRef = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let query = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> EncodedSearch in
                    try buffer.matchFixed("?")
                    return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
                }
            )
            return .init(mailboxUIDValidity: mailboxRef, encodedSearch: query)
        }
    }

    func parseIMAPURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> IMAPURL in
            try buffer.matchFixed("imap://")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
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

        return try buffer.parseOneOf(
            [
                { try parseRelativeIMAPURL_network(buffer: &$0, tracker: $1) },
                { try parseRelativeIMAPURL_absolute(buffer: &$0, tracker: $1) },
                { try parseRelativeIMAPURL_empty(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseMessagePath(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessagePath {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MessagePath in
            var ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)

            var uid = IUID(uid: 1)
            if ref.uidValidity == nil, let trimmed = ref.encodedMailbox.removingTrailingSlash() {
                try buffer.composite(tracker: tracker) { buffer, tracker in
                    ref.encodedMailbox = trimmed

                    uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
                }
            } else {
                uid = try self.parseIUID(buffer: &buffer, tracker: tracker)
            }

            var section = try buffer.parseOptional(tracker: tracker, parser: self.parseIMAPURLSection)
            var byteRange: MessagePath.ByteRange?
            // The section's trailing `/` may be the separator before `;PARTIAL=`: `1.2/;PARTIAL=1`.
            if let trimmed = section?.encodedSection.removingTrailingSlash(),
                let range = try buffer.parseOptional(
                    tracker: tracker,
                    parser: self.parseMessagePathByteRangeOnly
                )
            {
                section = URLMessageSection(encodedSection: trimmed)
                byteRange = range
            } else {
                byteRange = try buffer.parseOptional(
                    tracker: tracker,
                    parser: self.parseMessagePathByteRange
                )
            }
            return .init(mailboxReference: ref, iUID: uid, section: section, range: byteRange)
        }
    }

    func parseURLFetchType(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
        func parseURLFetchType_partialOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            let partial = try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseURLFetchType_sectionPartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchType {
            let section = try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
            if let trimmed = section.encodedSection.removingTrailingSlash(),
                let partial = try buffer.parseOptional(
                    tracker: tracker,
                    parser: self.parseMessagePathByteRangeOnly
                )
            {
                return .sectionPartial(section: URLMessageSection(encodedSection: trimmed), partial: partial)
            }
            let partial = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .sectionPartial(section: section, partial: partial)
        }

        func parseURLFetchType_uidSectionPartial(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> URLFetchType {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            let section = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> URLMessageSection in
                    try buffer.matchFixed("/")
                    return try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
                }
            )
            if let trimmed = section?.encodedSection.removingTrailingSlash(),
                let partial = try buffer.parseOptional(
                    tracker: tracker,
                    parser: self.parseMessagePathByteRangeOnly
                )
            {
                return .uidSectionPartial(
                    uid: uid,
                    section: URLMessageSection(encodedSection: trimmed),
                    partial: partial
                )
            }
            let partial = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseURLFetchType_refUidSectionPartial(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> URLFetchType {
            let ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            let section = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> URLMessageSection in
                    try buffer.matchFixed("/")
                    return try self.parseIMAPURLSectionOnly(buffer: &buffer, tracker: tracker)
                }
            )
            if let trimmed = section?.encodedSection.removingTrailingSlash(),
                let partial = try buffer.parseOptional(
                    tracker: tracker,
                    parser: self.parseMessagePathByteRangeOnly
                )
            {
                return .refUidSectionPartial(
                    ref: ref,
                    uid: uid,
                    section: URLMessageSection(encodedSection: trimmed),
                    partial: partial
                )
            }
            let partial = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        return try buffer.parseOneOf(
            [
                { try parseURLFetchType_refUidSectionPartial(buffer: &$0, tracker: $1) },
                { try parseURLFetchType_uidSectionPartial(buffer: &$0, tracker: $1) },
                { try parseURLFetchType_sectionPartial(buffer: &$0, tracker: $1) },
                { try parseURLFetchType_partialOnly(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseUChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try buffer.readByte()
            guard num.isUnreserved else {
                throw ParserError(hint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let num = try buffer.readByte()
            guard num.isSubDelimsSh else {
                throw ParserError(hint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            // FIXME: Better parser for this
            try buffer.matchFixed("%")
            var h1 = try buffer.readByte()
            var h2 = try buffer.readByte()

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

        return try buffer.parseOneOf(
            { try parseUChar_unreserved(buffer: &$0, tracker: $1) },
            { try parseUChar_subDelimsSH(buffer: &$0, tracker: $1) },
            { try parseUChar_pctEncoded(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseAChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseAChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try buffer.readByte()
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw ParserError(hint: "Expect achar, got \(char)")
            }
        }

        return try buffer.parseOneOf(
            { try parseUChar(buffer: &$0, tracker: $1) },
            { try parseAChar_other(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseBChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseBChar_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UInt8] {
            let char = try buffer.readByte()
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw ParserError(hint: "Expect bchar, got \(char)")
            }
        }

        return try buffer.parseOneOf(
            { try parseAChar(buffer: &$0, tracker: $1) },
            { try parseBChar_other(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseIUID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("/")
            return try parseIUIDOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseIUIDOnly(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IUID {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed(";UID=")
            return IUID(uid: try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker -> AuthenticatedURL in
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseAuthenticatedURLVerifier(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: rump, verifier: verifier)
        }
    }

    func parseURLRumpMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> RumpURLAndMechanism {
        try buffer.composite(tracker: tracker) { buffer, tracker -> RumpURLAndMechanism in
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    func parseURLFetchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLFetchData {
        try buffer.composite(tracker: tracker) { buffer, tracker -> URLFetchData in
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let data = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(url: url, data: data)
        }
    }

    func parseAuthenticatedURLRump(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AuthenticatedURLRump {
        try buffer.composite(tracker: tracker) { buffer, tracker -> AuthenticatedURLRump in
            let expiry = try buffer.parseOptional(tracker: tracker, parser: self.parseExpire)
            try buffer.matchFixed(";URLAUTH=")
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    func parseAuthenticatedURLVerifier(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> AuthenticatedURLVerifier {
        try buffer.composite(tracker: tracker) { buffer, tracker -> AuthenticatedURLVerifier in
            try buffer.matchFixed(":")
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(urlAuthMechanism: authMechanism, encodedAuthenticationURL: urlAuth)
        }
    }

    func parseUserAuthenticationMechanism(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> UserAuthenticationMechanism {
        try buffer.composite(tracker: tracker) { buffer, tracker -> UserAuthenticationMechanism in
            let encodedUser = try buffer.parseOptional(tracker: tracker, parser: self.parseEncodedUser)
            let authenticationMechanism = try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseIMAPURLAuthenticationMechanism
            )
            guard encodedUser != nil || authenticationMechanism != nil else {
                throw ParserError(hint: "Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, authenticationMechanism: authenticationMechanism)
        }
    }

    func parseFullDateTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDateTime {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("T")
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    func parseFullDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullDate {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    func parseFullTime(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try buffer.matchFixed(":")
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try buffer.matchFixed(":")
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try buffer.parseOptional(
            tracker: tracker,
            parser: { buffer, tracker -> FullTime.Fraction in
                try buffer.matchFixed(".")
                let digits = try buffer.parseOneOrMoreCharacters(where: \.isNum)
                return .init(unchecked: String(buffer: digits))
            }
        )
        let offset = try self.parseTimeOffset(buffer: &buffer, tracker: tracker)
        return .init(hour: hour, minute: minute, second: second, fraction: fraction, offset: offset)
    }

    // time-offset    = "Z" / time-numoffset
    // time-numoffset = ("+" / "-") time-hour ":" time-minute
    func parseTimeOffset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> FullTime.Offset {
        func parseNumericOffset(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (hour: Int, minute: Int) {
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            // time-hour = 00-23, time-minute = 00-59
            guard (0...23).contains(hour), (0...59).contains(minute) else {
                throw ParserError(hint: "Invalid time offset \(hour):\(minute)")
            }
            return (hour, minute)
        }

        return try buffer.parseOneOf(
            { buffer, tracker -> FullTime.Offset in
                // RFC 3339 Section 5.6: `Z` may be lowercase.
                try buffer.matchFixed("Z")
                return .utc
            },
            { buffer, tracker -> FullTime.Offset in
                try buffer.matchFixed("+")
                let (hour, minute) = try parseNumericOffset(buffer: &buffer, tracker: tracker)
                return .plus(hour: hour, minute: minute)
            },
            { buffer, tracker -> FullTime.Offset in
                try buffer.matchFixed("-")
                let (hour, minute) = try parseNumericOffset(buffer: &buffer, tracker: tracker)
                return .minus(hour: hour, minute: minute)
            },
            tracker: tracker
        )
    }

    func parseLiteralSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try self.parseLiteralSize(buffer: &buffer, tracker: tracker, maxLength: self.literalSizeLimit)
    }

    func parseLiteralSize(buffer: inout ParseBuffer, tracker: StackTracker, maxLength: Int) throws -> Int {
        try buffer.composite(tracker: tracker) { buffer, tracker -> Int in
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                try buffer.matchFixed("~")
            }
            try buffer.matchFixed("{")
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker, maxLength: maxLength)
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            return length
        }
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    func parseLiteral(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ByteBuffer in
            try buffer.matchFixed("{")
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                try buffer.matchFixed("+")
            }
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            let bytes = try buffer.extractBytes(length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    func parseLiteral8(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ByteBuffer in
            try buffer.matchFixed("~{")
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) in
                try buffer.matchFixed("+")
            }
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            let bytes = try buffer.extractBytes(length: length)
            if bytes.readableBytesView.contains(0) {
                throw ParserError(hint: "Found NUL byte in literal")
            }
            return bytes
        }
    }

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
            throw ExceededLiteralSizeLimitError(
                actualCount: length,
                maximumCount: maxLength
            )
        }
        return length
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    func parseMediaType(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.MediaType {
        func parseMediaTopLevel_defined(
            _ option: String,
            result: Media.TopLevelType,
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> Media.TopLevelType {
            try buffer.matchFixed("\"")
            try buffer.matchFixed(option)
            try buffer.matchFixed("\"")
            return result
        }

        func parseMediaTopLevel_application(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> Media.TopLevelType {
            try parseMediaTopLevel_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_audio(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.TopLevelType {
            try parseMediaTopLevel_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_image(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.TopLevelType {
            try parseMediaTopLevel_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_message(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.TopLevelType {
            try parseMediaTopLevel_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_video(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.TopLevelType {
            try parseMediaTopLevel_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.TopLevelType {
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(try decodeUTF8(parsed))
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker -> Media.MediaType in
            let topLevel = try buffer.parseOneOf(
                [
                    { try parseMediaTopLevel_application(buffer: &$0, tracker: $1) },
                    { try parseMediaTopLevel_audio(buffer: &$0, tracker: $1) },
                    { try parseMediaTopLevel_image(buffer: &$0, tracker: $1) },
                    { try parseMediaTopLevel_message(buffer: &$0, tracker: $1) },
                    { try parseMediaTopLevel_video(buffer: &$0, tracker: $1) },
                    { try parseMediaTopLevel_other(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
            try buffer.parseSpaces()
            let sub = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.MediaType(topLevel: topLevel, sub: sub)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    func parseMediaMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Subtype {
        let media = try self.parseMediaType(buffer: &buffer, tracker: tracker)
        guard
            media.topLevel == .message,
            media.sub == .rfc822
        else {
            throw ParserError(hint: "Failed to construct esearch source options")
        }
        return media.sub
    }

    // media-subtype   = string
    func parseMediaSubtype(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Subtype {
        let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
        let string = try decodeUTF8(parsed).lowercased()
        switch string {
        case "alternative":
            return .alternative
        case "mixed":
            return .mixed
        case "related":
            return .related
        default:
            return .init(string)
        }
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    func parseMediaText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Media.Subtype {
        try buffer.composite(tracker: tracker) { buffer, tracker -> Media.Subtype in
            try buffer.matchFixed("\"TEXT\" ")
            return try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
        }
    }

    func parseMetadataOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
        func parseMetadataOption_maxSize(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            try buffer.matchFixed("MAXSIZE ")
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseMetadataOption_maxSize(buffer: &$0, tracker: $1) },
            { try parseMetadataOption_scope(buffer: &$0, tracker: $1) },
            { try parseMetadataOption_param(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseMetadataOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataOption] {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("(")
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { buffer, tracker in
                    try buffer.parseSpaces()
                    return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseMetadataResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
        func parseMetadataResponse_values(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try buffer.matchFixed("METADATA ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try buffer.matchFixed("METADATA ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try buffer.parseOneOf(
            { try parseMetadataResponse_values(buffer: &$0, tracker: $1) },
            { try parseMetadataResponse_list(buffer: &$0, tracker: $1) },
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

        return try buffer.parseOneOf(
            { try parseMetadataValue_nstring(buffer: &$0, tracker: $1) },
            { try parseMetadataValue_literal8(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseMechanismBase64(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MechanismBase64 {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MechanismBase64 in
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try buffer.parseOptional(tracker: tracker) { buffer, tracker -> ByteBuffer in
                try buffer.matchFixed("=")
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    func parseGmailLabel(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
        func parseGmailLabel_backslash(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            try buffer.matchFixed("\\")
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(ByteBuffer(string: "\\\(att)"))
        }

        func parseGmailLabel_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(raw)
        }

        return try buffer.parseOneOf(
            { try parseGmailLabel_backslash(buffer: &$0, tracker: $1) },
            { try parseGmailLabel_string(buffer: &$0, tracker: $1) },
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
            try buffer.matchFixed("(")
            let descriptions = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: self.parseNamespaceDescription
            )
            try buffer.matchFixed(")")
            return descriptions
        }

        return try buffer.parseOneOf(
            { try parseNamespace_nil(buffer: &$0, tracker: $1) },
            { try parseNamespace_some(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    func parseNamespaceDescription(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UInt8? {
            try buffer.matchFixed("\"")
            // QUOTED-CHAR = <any TEXT-CHAR except quoted-specials> / "\" quoted-specials
            var byte = try buffer.readByte()
            if byte == UInt8(ascii: "\\") {
                byte = try buffer.readByte()
                guard byte.isQuotedSpecial else {
                    throw ParserError(hint: "Expected quoted special")
                }
            } else {
                guard byte.isQuotedChar else {
                    throw ParserError(hint: "Invalid character")
                }
            }
            try buffer.matchFixed("\"")
            return byte
        }

        func parseNamespaceDescr_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UInt8? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try buffer.matchFixed("(")
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let delimiter = try buffer.parseOneOf(
                { try parseNamespaceDescr_quotedChar(buffer: &$0, tracker: $1) },
                { try parseNamespaceDescr_nil(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .init(string: string, delimiterByte: delimiter, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    func parseNamespaceResponseExtensions(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> OrderedDictionary<ByteBuffer, [ByteBuffer]> {
        var kvs = OrderedDictionary<ByteBuffer, [ByteBuffer]>()
        try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
            (buffer, tracker) -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
        return kvs
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    func parseNamespaceResponseExtension(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<ByteBuffer, [ByteBuffer]> {
        try buffer.composite(tracker: tracker) { buffer, tracker -> KeyValue<ByteBuffer, [ByteBuffer]> in
            try buffer.parseSpaces()
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try buffer.parseSpaces()
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .init(key: s1, value: array)
        }
    }

    // SP Namespace SP Namespace SP Namespace
    func parseNamespaceResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try buffer.composite(tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try buffer.parseSpaces()
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // uidbatches-response = "UIDBATCHES" search-correlator
    //                       [SP uid-range *("," uid-range) ]
    func parseUIDBatchesResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDBatchesResponse {
        try buffer.composite(tracker: tracker) { buffer, tracker -> UIDBatchesResponse in
            let correlator = try parseSearchCorrelator(buffer: &buffer, tracker: tracker)
            let batches =
                try buffer.parseOptional(tracker: tracker) { buffer, tracker -> [UIDRange] in
                    try buffer.parseSpaces()
                    return try parseUIDRangeArray(buffer: &buffer, tracker: tracker)
                } ?? []
            return UIDBatchesResponse(correlator: correlator, batches: batches)
        }
    }

    // nil             = "NIL"
    func parseNil(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try buffer.matchFixed("nil")
    }

    // nstring         = string / nil
    func parseNString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try buffer.matchFixed("NIL")
            return nil
        }

        func parseNString_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try buffer.parseOneOf(
            { try parseNString_nil(buffer: &$0, tracker: $1) },
            { try parseNString_some(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // number          = 1*DIGIT
    func parseNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    func parseNZNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        try buffer.parseUnsignedInteger(tracker: tracker).number
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    func parseOptionExtension(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<OptionExtensionKind, OptionValueComp?> {
        func parseOptionExtensionKind_standard(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> OptionExtensionKind {
            .standard(.init(unchecked: try self.parseAtom(buffer: &buffer, tracker: tracker)))
        }

        func parseOptionExtensionKind_vendor(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try buffer.composite(tracker: tracker) {
            buffer,
            tracker -> KeyValue<OptionExtensionKind, OptionValueComp?> in
            let type = try buffer.parseOneOf(
                { try parseOptionExtensionKind_standard(buffer: &$0, tracker: $1) },
                { try parseOptionExtensionKind_vendor(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
            let value = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> OptionValueComp in
                try buffer.parseSpaces()
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    //
    // Left-recursive, so read as a sequence of `astring` / `"(" option-val-comp ")"`: one
    // element is itself, several are an `.array`. A parenthesized one is always an `.array`.
    func parseOptionValueComp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        let elements = try self.parseOptionValueCompSequence(buffer: &buffer, tracker: tracker)
        guard elements.count == 1 else { return .array(elements) }
        return elements[0]
    }

    private func parseOptionValueCompSequence(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> [OptionValueComp] {
        func parseElement_string(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseElement_parenthesized(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try buffer.matchFixed("(")
            let elements = try self.parseOptionValueCompSequence(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .array(elements)
        }

        func parseElement(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try buffer.parseOneOf(
                { try parseElement_string(buffer: &$0, tracker: $1) },
                { try parseElement_parenthesized(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            var elements = [try parseElement(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &elements, tracker: tracker) {
                (buffer, tracker) -> OptionValueComp in
                try buffer.parseSpaces()
                return try parseElement(buffer: &buffer, tracker: tracker)
            }
            return elements
        }
    }

    // option-value =  "(" option-val-comp ")"
    func parseOptionValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try buffer.composite(tracker: tracker) { buffer, tracker -> OptionValueComp in
            try buffer.matchFixed("(")
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    func parseOptionVendorTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OptionExtensionKind.Vendor {
        try buffer.composite(tracker: tracker) { buffer, tracker -> OptionExtensionKind.Vendor in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\(token)-\(atom)")
        }
    }

    // partial         = "<" number "." nz-number ">"
    func parsePartial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ClosedRange<UInt32> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> ClosedRange<UInt32> in
            try buffer.matchFixed("<")
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try buffer.matchFixed(".")
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try buffer.matchFixed(">")
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return num1...upper2.partialValue
        }
    }

    func parseByteRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteRange {
        func parseByteRange_length(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
            try buffer.matchFixed(".")
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) -> ByteRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try buffer.parseOptional(tracker: tracker) {
                try parseByteRange_length(buffer: &$0, tracker: $1)
            }
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
        try buffer.composite(tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try buffer.matchFixed("(")
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try buffer.parseSpaces()
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    // QUOTED-CHAR     = <any TEXT-CHAR except quoted-specials> /
    //                   "\" quoted-specials
    // quoted-specials = DQUOTE / "\"
    func parseQuoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ByteBuffer in
            try buffer.matchByte("\"")
            var hasQuotedSpecial = false
            var lastIsEscape = false
            let data = try buffer.parseZeroOrMoreCharacters { char in
                if lastIsEscape {
                    lastIsEscape = false
                    return true
                } else if char == UInt8(ascii: "\\") {
                    lastIsEscape = true
                    hasQuotedSpecial = true
                    return true
                } else if char == UInt8(ascii: "\"") {
                    return false
                } else {
                    return true
                }
            }
            try buffer.matchByte("\"")
            guard hasQuotedSpecial else { return data }
            // Replace '\\' with '\' and '\"' with '"':
            var escaped = data
            var unescaped = ByteBuffer()
            while let next = escaped.readBytes(length: 1)?.first {
                if next == UInt8(ascii: "\\") {
                    guard
                        let special = escaped.readBytes(length: 1)?.first,
                        special.isQuotedSpecial
                    else {
                        throw ParserError(
                            hint:
                                "Invalid escape in quoted string '\(String(decoding: data.readableBytesView, as: Unicode.UTF8.self))'"
                        )
                    }
                    unescaped.writeBytes([special])
                } else {
                    unescaped.writeBytes([next])
                }
            }
            return unescaped
        }
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    func parseReturnOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try buffer.matchFixed("SUBSCRIBED")
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try buffer.matchFixed("CHILDREN")
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_objectID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption {
            try buffer.matchFixed("OBJECTID")
            return .objectID
        }

        func parseReturnOption_optionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ReturnOption
        {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseReturnOption_subscribed(buffer: &$0, tracker: $1) },
                { try parseReturnOption_children(buffer: &$0, tracker: $1) },
                { try parseReturnOption_statusOption(buffer: &$0, tracker: $1) },
                { try parseReturnOption_objectID(buffer: &$0, tracker: $1) },
                { try parseReturnOption_optionExtension(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseScopeOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
        func parseScopeOption_zero(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try buffer.matchFixed("0")
            return .zero
        }

        func parseScopeOption_one(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try buffer.matchFixed("1")
            return .one
        }

        func parseScopeOption_infinity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ScopeOption {
            try buffer.matchFixed("infinity")
            return .infinity
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("DEPTH ")
            return try buffer.parseOneOf(
                { try parseScopeOption_zero(buffer: &$0, tracker: $1) },
                { try parseScopeOption_one(buffer: &$0, tracker: $1) },
                { try parseScopeOption_infinity(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }
    }

    // section         = "[" [section-spec] "]"
    func parseSection(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSection_none(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try buffer.composite(tracker: tracker) { buffer, tracker -> SectionSpecifier in
                try buffer.matchFixed("[]")
                return .complete
            }
        }

        func parseSection_some(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try buffer.matchFixed("[")
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("]")
            return spec
        }

        return try buffer.parseOneOf(
            { try parseSection_none(buffer: &$0, tracker: $1) },
            { try parseSection_some(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // section-binary  = "[" [section-part] "]"
    func parseSectionBinary(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try buffer.composite(tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try buffer.matchFixed("[")
            let part = try buffer.parseOptional(tracker: tracker, parser: self.parseSectionPart)
            try buffer.matchFixed("]")
            return part ?? .init([])
        }
    }

    // section-part    = nz-number *("." nz-number)
    func parseSectionPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try buffer.composite(tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try buffer.composite(tracker: tracker) { (buffer, tracker) -> Int in
                    try buffer.matchFixed(".")
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    func parseSectionSpecifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            try buffer.composite(tracker: tracker) { (buffer, tracker) -> SectionSpecifier in
                let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
                guard kind != .MIMEHeader else {
                    throw ParserError(hint: "Cannot use MIME with an empty section part")
                }
                return .init(kind: kind)
            }
        }

        func parseSectionSpecifier_withPart(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier
        {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                    try buffer.matchFixed(".")
                    return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
                } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try buffer.parseOneOf(
            { try parseSectionSpecifier_withPart(buffer: &$0, tracker: $1) },
            { try parseSectionSpecifier_noPart(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // section-text    = section-msgtext / "MIME"
    func parseSectionSpecifierKind(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            try buffer.matchFixed("MIME")
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER")
            return .header
        }

        func parseSectionSpecifierKind_headerFields(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER.FIELDS ")
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER.FIELDS.NOT ")
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            try buffer.matchFixed("TEXT")
            return .text
        }

        func parseSectionSpecifierKind_complete(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try buffer.parseOneOf(
            [
                { try parseSectionSpecifierKind_mime(buffer: &$0, tracker: $1) },
                { try parseSectionSpecifierKind_headerFields(buffer: &$0, tracker: $1) },
                { try parseSectionSpecifierKind_notHeaderFields(buffer: &$0, tracker: $1) },
                { try parseSectionSpecifierKind_header(buffer: &$0, tracker: $1) },
                { try parseSectionSpecifierKind_text(buffer: &$0, tracker: $1) },
                { try parseSectionSpecifierKind_complete(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseSelectParameter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
        func parseSelectParameter_basic(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter
        {
            try buffer.matchFixed("CONDSTORE")
            return .condStore
        }

        func parseSelectParameter_qresync(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try buffer.matchFixed("QRESYNC (")
            let uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUIDs = try buffer.parseOptional(
                tracker: tracker,
                parser: { (buffer, tracker) -> UIDSet in
                    try buffer.parseSpaces()
                    return try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                }
            )
            let seqMatchData = try buffer.parseOptional(
                tracker: tracker,
                parser: { (buffer, tracker) -> SequenceMatchData in
                    try buffer.parseSpaces()
                    return try self.parseSequenceMatchData(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return .qresync(
                .init(
                    uidValidity: uidValidity,
                    modificationSequenceValue: modSeqVal,
                    knownUIDs: knownUIDs,
                    sequenceMatchData: seqMatchData
                )
            )
        }

        func parseSelectParameter_objectID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SelectParameter {
            try buffer.matchFixed("OBJECTID")
            let compound = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> CompoundObjectID in
                try buffer.parseSpaces()
                return try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker)
            }
            return .objectID(compound)
        }

        return try buffer.parseOneOf(
            [
                { try parseSelectParameter_objectID(buffer: &$0, tracker: $1) },
                { try parseSelectParameter_qresync(buffer: &$0, tracker: $1) },
                { try parseSelectParameter_condstore(buffer: &$0, tracker: $1) },
                { try parseSelectParameter_basic(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    func parseParameters<Kind>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> OrderedDictionary<ExtensionKey<Kind>, ParameterValue?> {
        try buffer.composite(tracker: tracker) {
            (buffer, tracker) -> OrderedDictionary<ExtensionKey<Kind>, ParameterValue?> in
            try buffer.matchFixed(" (")
            var kvs = OrderedDictionary<ExtensionKey<Kind>, ParameterValue?>()
            let param: KeyValue<ExtensionKey<Kind>, ParameterValue?> =
                try self.parseParameter(buffer: &buffer, tracker: tracker)
            kvs[param.key] = param.value
            try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
                (buffer, tracker) -> KeyValue<ExtensionKey<Kind>, ParameterValue?> in
                try buffer.parseSpaces()
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return kvs
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    func parseStatusAttribute(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let parsed = try buffer.parseOneOrMoreCharacters { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        let string = try decodeUTF8(parsed)
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    func parseStatusOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try buffer.composite(tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try buffer.matchFixed("STATUS (")
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) -> MailboxAttribute in
                try buffer.parseSpaces()
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseStoreModifiers(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [StoreModifier] {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { (buffer, tracker) in
                    try buffer.parseSpaces()
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseStoreModifier(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
        func parseFetchModifier_unchangedSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier
        {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseFetchModifier_unchangedSince(buffer: &$0, tracker: $1) },
            { try parseFetchModifier_other(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseStoreOperation(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreOperation {
        try buffer.parseOneOf(
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try buffer.matchFixed("+")
                return .add
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try buffer.matchFixed("-")
                return .remove
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreOperation in
                try buffer.matchFixed("")
                return .replace
            },
            tracker: tracker
        )
    }

    func parseStoreSilent(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Bool {
        do {
            try buffer.matchFixed(".SILENT")
            return true
        } catch is ParserError {
            return false
        }
    }

    func parseStoreGmailLabels(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreGmailLabels {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("X-GM-LABELS", leadingSpaces: .rejected)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" (")
            var labels = [try self.parseGmailLabel(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &labels, tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
                return try self.parseGmailLabel(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .init(operation: operation, silent: silent, gmailLabels: labels)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    func parseStoreFlags(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreFlags_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [Flag] {
            var flags = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &flags, tracker: tracker) { buffer, tracker in
                try buffer.parseSpaces()
                return try self.parseFlag(buffer: &buffer, tracker: tracker)
            }
            return flags
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker -> StoreFlags in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("FLAGS", leadingSpaces: .rejected)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let flags = try buffer.parseOneOf(
                [
                    self.parseFlagList,
                    { try parseStoreFlags_array(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
            return .init(operation: operation, silent: silent, flags: flags)
        }
    }

    func parseStoreData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> StoreData {
        try buffer.parseOneOf(
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreData in
                let data = try self.parseStoreGmailLabels(buffer: &buffer, tracker: tracker)
                return .gmailLabels(data)
            },
            { (buffer: inout ParseBuffer, tracker: StackTracker) -> StoreData in
                let data = try self.parseStoreFlags(buffer: &buffer, tracker: tracker)
                return .flags(data)
            },
            tracker: tracker
        )
    }

    // string          = quoted / literal
    func parseString(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.parseOneOf(
            self.parseQuoted,
            self.parseLiteral,
            tracker: tracker
        )
    }

    /// Variant of `parseString()` allowing non-ASCII inside quoted strings.
    ///
    /// Not allowed by RFC 3501, but some emails have non-ASCII headers, and some servers
    /// end up copying the non-ASCII values into, for example, `BODYSTRUCTURE` parameters.
    func parseStringAllowingNonASCII(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.parseOneOf(
            self.parseQuoted,
            self.parseLiteral,
            tracker: tracker
        )
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    func parseTag(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command.Tag {
        let parsed = try buffer.parseOneOrMoreCharacters { $0.isTagChar }
        return Command.Tag(unchecked: try decodeUTF8(parsed))
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    func parseTaggedExtension<Kind>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<ExtensionKey<Kind>, ParameterValue> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let key: ExtensionKey<Kind> = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if String(key).lowercased() == "catenate" {
                throw ParserError(hint: "catenate extension")
            }

            try buffer.parseSpaces()
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    func parseParameterName<Kind>(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ExtensionKey<Kind> {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ExtensionKey<Kind> in

            let fchar = try buffer.readByte()
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar")
            }

            let parsed = try buffer.parseZeroOrMoreCharacters { char -> Bool in
                char.isTaggedLabelChar
            }
            let trailing = try decodeUTF8(parsed)
            return ExtensionKey(unchecked: String(decoding: [fchar], as: Unicode.UTF8.self) + trailing)
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
                try buffer.parseSpaces()
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
            into.append(try decodeUTF8(parsed))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws {
            try buffer.composite(tracker: tracker) { (buffer, tracker) in
                try buffer.matchFixed("(")
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try buffer.composite(tracker: tracker) { (buffer, tracker) in
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
            .sequence(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ParameterValue {
            try buffer.matchFixed("(")
            let comp =
                try buffer.parseOptional(tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try buffer.matchFixed(")")
            return .comp(comp)
        }

        return try buffer.parseOneOf(
            { try parseTaggedExtensionSimple_set(buffer: &$0, tracker: $1) },
            { try parseTaggedExtensionVal_comp(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // text            = 1*TEXT-CHAR
    func parseText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isTextChar
        }
    }

    // mechanism = "INTERNAL" / 1*(ALPHA / DIGIT / "-" / ".")
    func parseUAuthMechanism(buffer: inout ParseBuffer, tracker: StackTracker) throws -> URLAuthenticationMechanism {
        let parsed = try buffer.parseOneOrMoreCharacters { $0.isMechanismChar }
        return URLAuthenticationMechanism(unchecked: try decodeUTF8(parsed))
    }

    // userid          = astring
    func parseUserId(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        var astring = try self.parseAString(buffer: &buffer, tracker: tracker)
        // if this fails, something has gone very, very wrong
        return astring.readString(length: astring.readableBytes)!
    }

    // vendor-token     = atom (maybe?!?!?!)
    func parseVendorToken(buffer: inout ParseBuffer, tracker: StackTracker) throws -> String {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAlpha
        }
        return try decodeUTF8(parsed)
    }

    // resource-name     = "STORAGE" / "MESSAGE" / "MAILBOX" /
    //                     "ANNOTATION-STORAGE" / resource-name-ext
    // resource-name-ext = atom
    func parseQuotaResourceName(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> QuotaResource.Name {
        // An atom is exactly what a `Name` requires.
        QuotaResource.Name(unchecked: try parseAtom(buffer: &buffer, tracker: tracker))
    }

    // setquota_list   ::= "(" 0#setquota_resource ")"
    func parseQuotaLimits(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [QuotaLimit] {
        // setquota_resource ::= atom SP number
        func parseQuotaLimit(buffer: inout ParseBuffer, tracker: StackTracker) throws -> QuotaLimit {
            try buffer.composite(tracker: tracker) { (buffer, tracker) in
                try buffer.parseOptional(tracker: tracker, parser: { input, _ in try input.parseSpaces() })
                let resourceName = try parseQuotaResourceName(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaLimit(resourceName: resourceName, limit: limit)
            }
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws -> [QuotaLimit] in
            try buffer.matchFixed("(")
            let limits = try buffer.parseZeroOrMore(tracker: tracker) { try parseQuotaLimit(buffer: &$0, tracker: $1) }
            try buffer.matchFixed(")")
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
            try buffer.matchFixed("(")
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while try buffer.parseOptional(tracker: tracker, parser: { input, _ in try input.parseSpaces() }) != nil {
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
            }
            try buffer.matchFixed(")")
            guard let returnValue = Mailboxes(mailboxes) else {
                throw ParserError(hint: "Failed to unwrap mailboxes which should be impossible")
            }
            return returnValue
        }

        func parseSingleMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Mailboxes {
            let mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            guard let returnValue = Mailboxes(mailboxes) else {
                throw ParserError(hint: "Failed to unwrap single mailboxes which should be impossible")
            }
            return returnValue
        }

        return try buffer.parseOneOf(
            { try parseManyMailboxes(buffer: &$0, tracker: $1) },
            { try parseSingleMailboxes(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    func parseFilterMailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("selected")
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MailboxFilter {
            try buffer.matchFixed("selected-delayed")
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("inboxes")
            return .inboxes
        }

        func parseFilterMailboxes_Personal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("personal")
            return .personal
        }

        func parseFilterMailboxes_Subscribed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("subscribed")
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("subtree ")
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("mailboxes ")
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 7377
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try buffer.matchFixed("subtree-one ")
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseFilterMailboxes_SelectedDelayed(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_SubtreeOne(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Selected(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Inboxes(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Personal(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Subscribed(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Subtree(buffer: &$0, tracker: $1) },
                { try parseFilterMailboxes_Mailboxes(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // RFC 7377
    // scope-options =  scope-option *(SP scope-option)
    func parseExtendedSearchScopeOptions(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ExtendedSearchScopeOptions {
        var options = OrderedDictionary<ExtensionKey<ExtendedSearchScopeOptions>, ParameterValue?>()
        repeat {
            let param: KeyValue<ExtensionKey<ExtendedSearchScopeOptions>, ParameterValue?> =
                try parseParameter(buffer: &buffer, tracker: tracker)
            options[param.key] = param.value
        } while try buffer.parseOptional(tracker: tracker, parser: { input, _ in try input.parseSpaces() }) != nil
        guard let returnValue = ExtendedSearchScopeOptions(options) else {
            throw ParserError(hint: "Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
        return returnValue
    }

    // RFC 7377
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    func parseExtendedSearchSourceOptions(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ExtendedSearchSourceOptions {
        func parseExtendedSearchSourceOptions_spaceFilter(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MailboxFilter {
            try buffer.parseSpaces()
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseExtendedSearchSourceOptions_sourceMBox(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> [MailboxFilter] {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            while let anotherSource = try buffer.parseOptional(
                tracker: tracker,
                parser: { try parseExtendedSearchSourceOptions_spaceFilter(buffer: &$0, tracker: $1) }
            ) {
                sources.append(anotherSource)
            }
            return sources
        }

        func parseExtendedSearchSourceOptions_scopeOptions(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ExtendedSearchScopeOptions {
            try buffer.matchFixed(" (")
            let result = try parseExtendedSearchScopeOptions(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return result
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            try buffer.matchFixed("IN (")
            let sourceMbox = try parseExtendedSearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try buffer.parseOptional(
                tracker: tracker,
                parser: { try parseExtendedSearchSourceOptions_scopeOptions(buffer: &$0, tracker: $1) }
            )
            try buffer.matchFixed(")")
            guard let result = ExtendedSearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) else {
                throw ParserError(hint: "Failed to construct esearch source options")
            }
            return result
        }
    }

    // RFC 7377
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    // Ignoring the command here.
    func parseExtendedSearchOptions(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ExtendedSearchOptions {
        func parseExtendedSearchOptions_sourceOptions(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ExtendedSearchSourceOptions {
            try buffer.parseSpaces()
            let result = try parseExtendedSearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try buffer.parseOptional(
            tracker: tracker,
            parser: { try parseExtendedSearchOptions_sourceOptions(buffer: &$0, tracker: $1) }
        )
        let returnOpts =
            try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseSearchReturnOptions
            ) ?? []
        try buffer.parseSpaces()
        let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
        return ExtendedSearchOptions(
            key: program,
            charset: charset,
            returnOptions: returnOpts,
            sourceOptions: sourceOptions
        )
    }

    // RFC 8474
    // objectid = 1*255(ALPHA / DIGIT / "_" / "-")
    func parseObjectID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ObjectID {
        let parsed = try buffer.parseZeroOrMoreCharacters { char -> Bool in
            char.isObjectIDChar
        }
        let string = try decodeUTF8(parsed)
        guard let objectID = ObjectID(string) else {
            throw ParserError(hint: "Invalid object ID.")
        }
        return objectID
    }

    // OBJECTID+
    // objectid-key = "MAILBOXID" / "ACCOUNTID" / "EMAILID" / "THREADID" / atom
    // objectid-kvpair = objectid-key SP objectid
    // objectid-compound = "OBJECTID" SP "(" [objectid-kvpair *(SP objectid-kvpair)] ")"
    func parseCompoundObjectID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CompoundObjectID {
        enum Pair {
            case mailboxID(MailboxID)
            case accountID(AccountID)
            case emailID(EmailID)
            case threadID(ThreadID)
            case unknown
        }

        func parsePair_mailboxID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            try buffer.matchFixed("MAILBOXID ")
            return .mailboxID(MailboxID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_accountID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            try buffer.matchFixed("ACCOUNTID ")
            return .accountID(AccountID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_emailID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            try buffer.matchFixed("EMAILID ")
            return .emailID(EmailID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_threadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            try buffer.matchFixed("THREADID ")
            return .threadID(ThreadID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        // Unrecognized keys, and their values, are parsed and discarded. Clients MUST ignore
        // unrecognized key-value pairs so that future extensions can add new identifier types.
        func parsePair_unknown(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            _ = try self.parseAtom(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            _ = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .unknown
        }

        func parsePair(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Pair {
            try buffer.parseOneOf(
                [
                    { try parsePair_mailboxID(buffer: &$0, tracker: $1) },
                    { try parsePair_accountID(buffer: &$0, tracker: $1) },
                    { try parsePair_emailID(buffer: &$0, tracker: $1) },
                    { try parsePair_threadID(buffer: &$0, tracker: $1) },
                    { try parsePair_unknown(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) -> CompoundObjectID in
            try buffer.matchFixed("(")

            var pairs: [Pair] = []
            if let first = try buffer.parseOptional(
                tracker: tracker,
                parser: { try parsePair(buffer: &$0, tracker: $1) }
            ) {
                pairs.append(first)
                try buffer.parseZeroOrMore(into: &pairs, tracker: tracker) {
                    (buffer, tracker) -> Pair in
                    try buffer.parseSpaces()
                    return try parsePair(buffer: &buffer, tracker: tracker)
                }
            }

            try buffer.matchFixed(")")

            var compound = CompoundObjectID()
            for pair in pairs {
                switch pair {
                case .mailboxID(let value):
                    compound.mailboxID = value
                case .accountID(let value):
                    compound.accountID = value
                case .emailID(let value):
                    compound.emailID = value
                case .threadID(let value):
                    compound.threadID = value
                case .unknown:
                    break
                }
            }
            return compound
        }
    }

    /// Parses an object ID leniently: any run of bytes up to a delimiter (space, `)`, `]`, CR, LF) is consumed,
    /// and `nil` is returned if it isn't a valid ``ObjectID`` rather than failing the parse.
    func parseObjectIDLeniently(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ObjectID? {
        let parsed = try buffer.parseZeroOrMoreCharacters { char -> Bool in
            switch char {
            case UInt8(ascii: " "), UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "\r"), UInt8(ascii: "\n"):
                return false
            default:
                return true
            }
        }
        // Non-UTF-8 bytes become U+FFFD, which isn't a valid object ID character.
        return ObjectID(String(decoding: parsed.readableBytesView, as: UTF8.self))
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
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            let (num, size) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
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

    static var makeNewDefault: StackTracker {
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
