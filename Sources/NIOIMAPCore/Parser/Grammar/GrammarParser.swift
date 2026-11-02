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
    /// - Throws: ``ParseFailure/incomplete`` when every byte that has arrived is part of the keyword,
    ///     since more could still follow; ``ParseFailure/mismatch(_:)`` when the first byte cannot start
    ///     one.
    func parseLookupKeyword(buffer: inout ParseInput) throws(ParseFailure) -> String {
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
    /// Pass an annotated closure: `{ keyword, buffer throws(ParseFailure) in switch keyword { … } }`.
    ///
    /// - Important: `select` should throw ``ParseFailure/mismatch(_:)`` for an unrecognised keyword —
    ///     not ``ParseFailure/incomplete``, which would make the caller wait for bytes that cannot help.
    ///     The type can't enforce this. Callers that fall back to another production
    ///     (`parseFetchAttribute`, say) catch exactly `.mismatch`.
    func selectingKeyword<T>(
        buffer: inout ParseInput,
        _ select: (String, inout ParseInput) throws(ParseFailure) -> T
    ) throws(ParseFailure) -> T {
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
    func parseAString(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        func parseOneOrMoreASTRINGCHAR(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [UInt8] {
            try buffer.parseOneOrMoreCharacters { char -> Bool in
                char.isAStringChar
            }
        }
        return try buffer.parseOneOf(
            self.parseString,
            { b, t throws(ParseFailure) in try parseOneOrMoreASTRINGCHAR(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // atom            = 1*ATOM-CHAR
    func parseAtom(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar
        }
        let string = try decodeUTF8(parsed)
        return self.parsedStringCache(string)
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    func parseAttributeFlag(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AttributeFlag {
        func parseAttributeFlag_slashed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> AttributeFlag {
            try buffer.matchFixed("\\\\")
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: atom)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseAttributeFlag_slashed(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseAttributeFlag_unslashed(buffer: &b, tracker: t) },
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
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> AuthenticationMechanism {
        let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
        guard let mechanism = AuthenticationMechanism(atom) else {
            throw .mismatch(dynamicHint: "Invalid authentication mechanism name: \(atom)")
        }
        return mechanism
    }

    func parseAuthenticatedURL(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> NetworkMessagePath {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> NetworkMessagePath in
            try buffer.matchFixed("imap://")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let messagePath = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePath: messagePath)
        }
    }

    func parseAuthIMAPURLFull(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> FullAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> FullAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(networkMessagePath: imapURL, authenticatedURL: urlAuth)
        }
    }

    func parseAuthIMAPURLRump(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> RumpAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> RumpAuthenticatedURL in
            let imapURL = try self.parseAuthenticatedURL(buffer: &buffer, tracker: tracker)
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: imapURL, authenticatedURLRump: rump)
        }
    }

    func parseInitialResponse(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> InitialResponse {
        func parseInitialResponse_empty(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> InitialResponse {
            try buffer.matchFixed("=")
            return .empty
        }

        func parseInitialResponse_data(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> InitialResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .init(base64)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseInitialResponse_empty(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseInitialResponse_data(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // base64          = *(4base64-char) [base64-terminal]
    func parseBase64(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UInt8] in
            let bytes = try buffer.parseZeroOrMoreCharacters {
                $0.isBase64Char || $0 == UInt8(ascii: "=")
            }
            do {
                return try Base64.decode(bytes: bytes)
            } catch {
                throw .mismatch(dynamicHint: "Invalid base64 \(error)")
            }
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    func parseCapability(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(unchecked: string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    func parseCapabilityData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [Capability] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [Capability] in
            try buffer.matchFixed("CAPABILITY")
            return try self.parseCapabilitySuffix(buffer: &buffer, tracker: tracker)
        }
    }

    // *(SP capability)
    func parseCapabilitySuffix(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [Capability] {
        try buffer.parseOneOrMore(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.parseSpaces()
            return try self.parseCapability(buffer: &buffer, tracker: tracker)
        }
    }

    // charset          = atom / quoted
    func parseCharset(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CharacterSetName {
        func parseCharset_atom(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> CharacterSetName {
            CharacterSetName(unchecked: try parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseCharset_quoted(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> CharacterSetName {
            let bytes = try parseQuoted(buffer: &buffer, tracker: tracker)
            let string = String(decoding: bytes, as: UTF8.self)
            // `parseQuoted` is lenient (CR, LF, 8-bit, empty); reject what can't be written back.
            guard let name = CharacterSetName(string) else {
                throw .mismatch(dynamicHint: "Invalid charset \(String(reflecting: string))")
            }
            return name
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseCharset_atom(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseCharset_quoted(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseChangedSinceModifier(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ChangedSinceModifier {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> ChangedSinceModifier in
            try buffer.matchFixed("CHANGEDSINCE ")
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    func parseUnchangedSinceModifier(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> UnchangedSinceModifier {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> UnchangedSinceModifier in
            try buffer.matchFixed("UNCHANGEDSINCE ")
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    func parseChildinfoExtendedItem(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [ListSelectBaseOption] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [ListSelectBaseOption] in
            try buffer.matchFixed("CHILDINFO (")
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ListSelectBaseOption in
                try buffer.parseSpaces()
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    // condstore-param = "CONDSTORE"
    func parseConditionalStoreParameter(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
        try buffer.matchFixed("CONDSTORE")
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    func parseContinuationRequest(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ContinuationRequest {
        func parseContinuationRequest_base64(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ContinuationRequest {
            try buffer.parseSpaces()
            let base64 = try self.parseBase64(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()

            guard !base64.isEmpty else {
                throw .mismatch()
            }

            return .data(base64)
        }

        func parseContinuationRequest_responseText(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ContinuationRequest {
            try buffer.parseSpaces()
            let responseText = try self.parseResponseText(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            return .responseText(responseText)
        }

        // Allow no space and no additional text after "+":
        func parseContinuationRequest_empty(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ContinuationRequest {
            try buffer.matchNewline()
            return .responseText(ResponseText(code: nil, text: ""))
        }

        try buffer.matchFixed("+")
        let p1 = ParseAlternative<ContinuationRequest> { b, t throws(ParseFailure) in
            try parseContinuationRequest_base64(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<ContinuationRequest> { b, t throws(ParseFailure) in
            try parseContinuationRequest_responseText(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<ContinuationRequest> { b, t throws(ParseFailure) in
            try parseContinuationRequest_empty(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3], tracker: tracker)
    }

    // create-param = create-param-name [SP create-param-value]
    func parseCreateParameters(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [CreateParameter] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.matchFixed(" (")
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseCreateParameter(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CreateParameter {
        func parseCreateParameter_parameter(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> CreateParameter {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> CreateParameter {
            try buffer.matchFixed("USE (")
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.parseSpaces()
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .attributes(array)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseCreateParameter_specialUse(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseCreateParameter_parameter(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseParameter<Kind>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<ExtensionKey<Kind>, ParameterValue?> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let name: ExtensionKey<Kind> = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ParameterValue in
                try buffer.parseSpaces()
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: value)
        }
    }

    func parseUseAttribute(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> UseAttribute {
        func parseUseAttribute_fixed(
            expected: String,
            returning: UseAttribute,
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try buffer.matchFixed(expected)
            return returning
        }

        func parseUseAttribute_all(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\All", returning: .all, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_archive(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Archive", returning: .archive, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_drafts(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Drafts", returning: .drafts, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_flagged(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Flagged", returning: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_junk(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Junk", returning: .junk, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_sent(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Sent", returning: .sent, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_trash(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Trash", returning: .trash, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_snoozed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Snoozed", returning: .snoozed, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_scheduled(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(
                expected: "\\Scheduled",
                returning: .scheduled,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseUseAttribute_memos(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Memos", returning: .memos, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_other(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UseAttribute {
            try buffer.matchFixed("\\")
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\\" + att)
        }

        let p1 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_all(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_archive(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_drafts(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_flagged(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_junk(buffer: &b, tracker: t)
        }
        let p6 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_sent(buffer: &b, tracker: t)
        }
        let p7 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_trash(buffer: &b, tracker: t)
        }
        let p8 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_snoozed(buffer: &b, tracker: t)
        }
        let p9 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_scheduled(buffer: &b, tracker: t)
        }
        let p10 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_memos(buffer: &b, tracker: t)
        }
        let p11 = ParseAlternative<UseAttribute> { b, t throws(ParseFailure) in
            try parseUseAttribute_other(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11], tracker: tracker)
    }

    func parseEncodedAuthenticationType(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> EncodedAuthenticationType {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedAuthenticationType in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseAChar).reduce([], +)
            let string = String(decoding: array, as: Unicode.UTF8.self)
            guard string != EncodedAuthenticationType.anyMechanism else {
                throw .mismatch("`*` is any mechanism, not an enc-auth-type")
            }
            return .init(unchecked: string)
        }
    }

    func parseEncodedMailbox(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> EncodedMailbox {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedMailbox in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSearch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> EncodedSearch {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedSearch in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedSection(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> EncodedSection {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedSection in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedUser(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> EncodedUser {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedUser in
            let array = try buffer.parseOneOrMore(tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(unchecked: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    func parseEncodedURLAuth(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> EncodedAuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedAuthenticatedURL in
            // `32*HEXDIG`
            let bytes = try buffer.parseOneOrMoreCharacters(where: \.isHexCharacter)
            guard bytes.count >= EncodedAuthenticatedURL.minimumLength else {
                throw .mismatch(
                    dynamicHint: "Expected at least 32 hex digits, got \(String(decoding: bytes, as: UTF8.self))"
                )
            }
            return .init(unchecked: String(decoding: bytes, as: UTF8.self))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    func parseEnableData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [Capability] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [Capability] in
            try buffer.matchFixed("ENABLED")
            return try buffer.parseZeroOrMore(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> Capability in
                try buffer.parseSpaces()
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)

    func parseExtendedSearchResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ExtendedSearchResponse {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let correlator = try buffer.parseOptional(tracker: tracker, parser: self.parseSearchCorrelator)
            let kind: ExtendedSearchResponse.Kind =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                    try buffer.matchFixed(" UID")
                    return .uid
                } ?? .sequenceNumber
            let searchReturnData = try buffer.parseZeroOrMore(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> SearchReturnData in
                try buffer.parseSpaces()
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ExtendedSearchResponse(correlator: correlator, kind: kind, returnData: searchReturnData)
        }
    }

    func parseExpire(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Expire {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Expire in
            try buffer.matchFixed(";EXPIRE=")
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    func parseAccess(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Access {
        func parseAccess_submit(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Access {
            try buffer.matchFixed("submit+")
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Access {
            try buffer.matchFixed("user+")
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authenticatedUser(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Access {
            try buffer.matchFixed("authuser")
            return .authenticateUser
        }

        func parseAccess_anonymous(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Access {
            try buffer.matchFixed("anonymous")
            return .anonymous
        }

        let p1 = ParseAlternative<Access> { b, t throws(ParseFailure) in
            try parseAccess_submit(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<Access> { b, t throws(ParseFailure) in try parseAccess_user(buffer: &b, tracker: t) }
        let p3 = ParseAlternative<Access> { b, t throws(ParseFailure) in
            try parseAccess_authenticatedUser(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<Access> { b, t throws(ParseFailure) in
            try parseAccess_anonymous(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4], tracker: tracker)
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    func parseFilterName(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey.FilterName {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
        return SearchKey.FilterName(unchecked: try decodeUTF8(parsed))
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    func parseFlag(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Flag {
        func parseFlag_keyword(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        let p1 = ParseAlternative<Flag> { b, t throws(ParseFailure) in try parseFlag_keyword(buffer: &b, tracker: t) }
        let p2 = ParseAlternative<Flag> { b, t throws(ParseFailure) in try parseFlag_extension(buffer: &b, tracker: t) }
        return try buffer.parseOneOf([p1, p2], tracker: tracker)
    }

    // flag-extension  = "\" atom
    func parseFlagExtension(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> String in
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
    func parseFlagKeyword(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Flag.Keyword {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAtomChar || char.isResponseSpecial
        }
        let string = try self.parsedStringCache(decodeUTF8(parsed))
        return Flag.Keyword(unchecked: string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    func parseFlagList(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [Flag] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("(")
            let flags =
                try buffer.parseOptional(tracker: tracker) { (buffer, _) throws(ParseFailure) -> [Flag] in
                    var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                    try buffer.parseZeroOrMore(into: &output, tracker: tracker) {
                        buffer,
                        tracker throws(ParseFailure) in
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

        parseFlagPerm(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> PermanentFlag
    {
        func parseFlagPerm_wildcard(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> PermanentFlag {
            try buffer.matchFixed("\\*")
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseFlagPerm_wildcard(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseFlagPerm_flag(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // header-fld-name = astring
    func parseHeaderFieldName(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        let bytes = try self.parseAString(buffer: &buffer, tracker: tracker)
        return String(decoding: bytes, as: UTF8.self)
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    func parseHeaderList(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [String] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [String] in
            try buffer.matchFixed("(")
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> String in
                try buffer.parseSpaces()
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return output
        }
    }

    // resp-jmapaccess = "JMAPACCESS" SP quoted
    func parseJMAPAccess(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ResponsePayload.JMAPAccessURL {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker throws(ParseFailure) -> ResponsePayload.JMAPAccessURL in
            try buffer.matchFixed("JMAPACCESS")
            try buffer.parseSpaces()
            let bytes = try parseQuoted(buffer: &buffer, tracker: tracker)
            let string = String(decoding: bytes, as: UTF8.self)
            guard let components = URLComponents(string: string) else {
                throw .mismatch("Couldn't parse JMAPACCESS URL")
            }
            guard
                let url = components.url,
                let jmapAccessURL = ResponsePayload.JMAPAccessURL(url)
            else {
                throw .mismatch("Invalid JMAPACCESS URL")
            }
            return jmapAccessURL
        }
    }

    func parseURLCommand(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> URLCommand {
        func parseURLCommand_list(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> URLCommand {
            .messageList(try self.parseEncodedSearchQuery(buffer: &buffer, tracker: tracker))
        }

        func parseURLCommand_part(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> URLCommand {
            let path = try self.parseMessagePath(buffer: &buffer, tracker: tracker)
            let auth = try buffer.parseOptional(tracker: tracker, parser: self.parseIURLAuth)
            return .fetch(path: path, authenticatedURL: auth)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseURLCommand_part(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseURLCommand_list(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseNetworkPath(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> NetworkPath {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> NetworkPath in
            try buffer.matchFixed("//")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
            return .init(server: server, query: command)
        }
    }

    func parseLastCommandSet<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker,
        setParser: SubParser<MessageIdentifierSetNonEmpty<T>>
    ) throws(ParseFailure) -> LastCommandSet<T> {
        func parseLastCommandSet_lastCommand(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandSet<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        func parseLastCommandSet_set(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandSet<T> {
            .set(try setParser(&buffer, tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseLastCommandSet_lastCommand(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseLastCommandSet_set(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseLastCommandMessageID<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker,
        setParser: SubParser<T>
    ) throws(ParseFailure) -> LastCommandMessageID<T> {
        func parseLastCommandMessageID_lastCommand(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandMessageID<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        func parseLastCommandMessageID_id(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandMessageID<T> {
            .id(try setParser(&buffer, tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseLastCommandMessageID_lastCommand(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseLastCommandMessageID_id(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseAbsoluteMessagePath(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> AbsoluteMessagePath {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> AbsoluteMessagePath in
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
            return .init(command: command)
        }
    }

    func parseIMAPURLAuthenticationMechanism(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> IMAPURLAuthenticationMechanism {
        func parseIMAPURLAuthenticationMechanism_any(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> IMAPURLAuthenticationMechanism {
            try buffer.matchFixed("*")
            return .any
        }

        func parseIMAPURLAuthenticationMechanism_encoded(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> IMAPURLAuthenticationMechanism {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.matchFixed(";AUTH=")
            // Longest match first: `;AUTH=*x` is the type `*x`, not any mechanism.
            return try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseIMAPURLAuthenticationMechanism_encoded(buffer: &b, tracker: t)
                },
                { b, t throws(ParseFailure) in try parseIMAPURLAuthenticationMechanism_any(buffer: &b, tracker: t) },
                tracker: tracker
            )
        }
    }

    // id-response = "ID" SP id-params-list
    func parseIDResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> OrderedDictionary<String, String?> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.matchFixed("ID ")
            let result = try parseIDParamsList(buffer: &buffer, tracker: tracker)
            // datamail.in appends a `+` here for some reason.
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.matchByte("+")
            }
            return result
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    func parseIDParamsList(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> OrderedDictionary<String, String?> {
        func parseIDValue(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String? {
            guard let value = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return nil
            }
            do {
                return try ModifiedUTF7.decode(value)
            } catch {
                throw ParseFailure(error)
            }
        }

        func parseIDParamsList_nil(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OrderedDictionary<String, String?> {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return [:]
        }

        func parseIDParamsList_element(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> (String, String?) {
            let parsedKey = try self.parseString(buffer: &buffer, tracker: tracker)
            let key = try decodeUTF8(parsedKey)
            try buffer.parseSpaces()
            return (key, try parseIDValue(buffer: &buffer, tracker: tracker))
        }

        func parseIDParamsList_empty(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OrderedDictionary<String, String?> {
            try buffer.matchFixed("(")
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
            }
            try buffer.matchFixed(")")
            return [:]
        }

        func parseIDParamsList_some(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OrderedDictionary<String, String?> {
            try buffer.matchFixed("(")
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
            }
            let (key, value) = try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            var dic: OrderedDictionary<String, String?> = [key: value]
            try buffer.parseZeroOrMore(into: &dic, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> (String, String?) in
                try buffer.parseSpaces()
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            _ = try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
            }
            try buffer.matchFixed(")")
            return dic
        }
        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseIDParamsList_nil(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseIDParamsList_empty(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseIDParamsList_some(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseIdleDone(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
        try buffer.matchFixed("DONE")
        try buffer.matchNewline()
    }

    func parseMessagePathByteRange(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MessagePath.ByteRange {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MessagePath.ByteRange in
            try buffer.matchFixed("/")
            return try parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseMessagePathByteRangeOnly(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MessagePath.ByteRange {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MessagePath.ByteRange in
            try buffer.matchFixed(";PARTIAL=")
            return .init(range: try self.parseByteRange(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSection(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> URLMessageSection {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> URLMessageSection in
            try buffer.matchFixed("/;SECTION=")
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPURLSectionOnly(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> URLMessageSection {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> URLMessageSection in
            try buffer.matchFixed(";SECTION=")
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIMAPServer(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IMAPServer {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> IMAPServer in
            let info = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> UserAuthenticationMechanism in
                    let info = try self.parseUserAuthenticationMechanism(buffer: &buffer, tracker: tracker)
                    try buffer.matchFixed("@")
                    return info
                }
            )
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> Int in
                    try buffer.matchFixed(":")
                    return try self.parseNumber(buffer: &buffer, tracker: tracker)
                }
            )
            guard let port else {
                return .init(userAuthenticationMechanism: info, host: host, port: nil)
            }
            guard let validPort = UInt16(exactly: port) else {
                throw .mismatch(dynamicHint: "Port \(port) out of range")
            }
            return .init(userAuthenticationMechanism: info, host: host, port: validPort)
        }
    }

    /// Reads the longest run of `host` characters, then validates it as a whole: `[::1]`,
    /// `192.0.2.1`, `imap.example.com`.
    func parseHost(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IMAPServer.Host {
        func parseHost_ipLiteral(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
            try buffer.matchFixed("[")
            let address = try buffer.parseOneOrMoreCharacters {
                $0.isUnreserved || $0.isSubDelims || $0 == UInt8(ascii: ":")
            }
            try buffer.matchFixed("]")
            return "[\(String(decoding: address, as: UTF8.self))]"
        }

        func parseHost_registeredName(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
            let name = try buffer.parseZeroOrMoreCharacters {
                URLCharacterClass.registeredName.contains($0) || $0 == UInt8(ascii: "%")
            }
            return String(decoding: name, as: UTF8.self)
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let string = try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseHost_ipLiteral(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseHost_registeredName(buffer: &b, tracker: t) },
                tracker: tracker
            )
            guard let host = IMAPServer.Host(string) else {
                throw .mismatch(dynamicHint: "Invalid host \(string)")
            }
            return host
        }
    }

    func parseEncodedMailboxUIDValidity(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MailboxUIDValidity {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MailboxUIDValidity in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> UIDValidity in
                    try buffer.matchFixed(";UIDVALIDITY=")
                    return try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
                }
            )
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    func parseEncodedSearchQuery(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> EncodedSearchQuery {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> EncodedSearchQuery in
            let mailboxRef = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let query = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> EncodedSearch in
                    try buffer.matchFixed("?")
                    return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
                }
            )
            return .init(mailboxUIDValidity: mailboxRef, encodedSearch: query)
        }
    }

    func parseIMAPURL(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IMAPURL {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> IMAPURL in
            try buffer.matchFixed("imap://")
            let server = try self.parseIMAPServer(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("/")
            let command = try buffer.parseOptional(tracker: tracker, parser: self.parseURLCommand)
            return .init(server: server, query: command)
        }
    }

    func parseRelativeIMAPURL(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> RelativeIMAPURL {
        func parseRelativeIMAPURL_absolute(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> RelativeIMAPURL {
            .absolutePath(try self.parseAbsoluteMessagePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_network(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> RelativeIMAPURL {
            .networkPath(try self.parseNetworkPath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_empty(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> RelativeIMAPURL {
            .empty
        }

        let p1 = ParseAlternative<RelativeIMAPURL> { b, t throws(ParseFailure) in
            try parseRelativeIMAPURL_network(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<RelativeIMAPURL> { b, t throws(ParseFailure) in
            try parseRelativeIMAPURL_absolute(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<RelativeIMAPURL> { b, t throws(ParseFailure) in
            try parseRelativeIMAPURL_empty(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3], tracker: tracker)
    }

    func parseMessagePath(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MessagePath {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MessagePath in
            var ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)

            var uid = IUID(uid: 1)
            if ref.uidValidity == nil, let trimmed = ref.encodedMailbox.removingTrailingSlash() {
                try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
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

    func parseURLFetchType(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> URLFetchType {
        func parseURLFetchType_partialOnly(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> URLFetchType {
            let partial = try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseURLFetchType_sectionPartial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> URLFetchType {
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
                parser: { buffer, tracker throws(ParseFailure) -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .sectionPartial(section: section, partial: partial)
        }

        func parseURLFetchType_uidSectionPartial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> URLFetchType {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            let section = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> URLMessageSection in
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
                parser: { buffer, tracker throws(ParseFailure) -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseURLFetchType_refUidSectionPartial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> URLFetchType {
            let ref = try self.parseEncodedMailboxUIDValidity(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            let section = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> URLMessageSection in
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
                parser: { buffer, tracker throws(ParseFailure) -> MessagePath.ByteRange in
                    try buffer.matchFixed("/")
                    return try self.parseMessagePathByteRangeOnly(buffer: &buffer, tracker: tracker)
                }
            )
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        let p1 = ParseAlternative<URLFetchType> { b, t throws(ParseFailure) in
            try parseURLFetchType_refUidSectionPartial(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<URLFetchType> { b, t throws(ParseFailure) in
            try parseURLFetchType_uidSectionPartial(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<URLFetchType> { b, t throws(ParseFailure) in
            try parseURLFetchType_sectionPartial(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<URLFetchType> { b, t throws(ParseFailure) in
            try parseURLFetchType_partialOnly(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4], tracker: tracker)
    }

    func parseUChar(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
            let num = try buffer.readByte()
            guard num.isUnreserved else {
                throw .mismatch(dynamicHint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
            let num = try buffer.readByte()
            guard num.isSubDelimsSh else {
                throw .mismatch(dynamicHint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
            // FIXME: Better parser for this
            try buffer.matchFixed("%")
            var h1 = try buffer.readByte()
            var h2 = try buffer.readByte()

            guard h1.isHexCharacter, h2.isHexCharacter else {
                throw .mismatch(dynamicHint: "Expected 2 hex digits, got \(h1) and \(h2)")
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
            { b, t throws(ParseFailure) in try parseUChar_unreserved(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseUChar_subDelimsSH(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseUChar_pctEncoded(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseAChar(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        func parseAChar_other(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
            let char = try buffer.readByte()
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw .mismatch(dynamicHint: "Expect achar, got \(char)")
            }
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseUChar(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseAChar_other(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseBChar(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        func parseBChar_other(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
            let char = try buffer.readByte()
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw .mismatch(dynamicHint: "Expect bchar, got \(char)")
            }
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseAChar(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseBChar_other(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseIUID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IUID {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("/")
            return try parseIUIDOnly(buffer: &buffer, tracker: tracker)
        }
    }

    func parseIUIDOnly(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IUID {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed(";UID=")
            return IUID(uid: try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }
    }

    func parseIURLAuth(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AuthenticatedURL {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> AuthenticatedURL in
            let rump = try self.parseAuthenticatedURLRump(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseAuthenticatedURLVerifier(buffer: &buffer, tracker: tracker)
            return .init(authenticatedURL: rump, verifier: verifier)
        }
    }

    func parseURLRumpMechanism(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> RumpURLAndMechanism {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> RumpURLAndMechanism in
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    func parseURLFetchData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> URLFetchData {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> URLFetchData in
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let data = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(url: url, data: data)
        }
    }

    func parseAuthenticatedURLRump(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> AuthenticatedURLRump {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> AuthenticatedURLRump in
            let expiry = try buffer.parseOptional(tracker: tracker, parser: self.parseExpire)
            try buffer.matchFixed(";URLAUTH=")
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    func parseAuthenticatedURLVerifier(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> AuthenticatedURLVerifier {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> AuthenticatedURLVerifier in
            try buffer.matchFixed(":")
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(urlAuthMechanism: authMechanism, encodedAuthenticationURL: urlAuth)
        }
    }

    func parseUserAuthenticationMechanism(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> UserAuthenticationMechanism {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> UserAuthenticationMechanism in
            let encodedUser = try buffer.parseOptional(tracker: tracker, parser: self.parseEncodedUser)
            let authenticationMechanism = try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseIMAPURLAuthenticationMechanism
            )
            guard encodedUser != nil || authenticationMechanism != nil else {
                throw .mismatch("Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, authenticationMechanism: authenticationMechanism)
        }
    }

    func parseFullDateTime(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FullDateTime {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("T")
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    func parseFullDate(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FullDate {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    func parseFullTime(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try buffer.matchFixed(":")
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try buffer.matchFixed(":")
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try buffer.parseOptional(
            tracker: tracker,
            parser: { buffer, tracker throws(ParseFailure) -> FullTime.Fraction in
                try buffer.matchFixed(".")
                let digits = try buffer.parseOneOrMoreCharacters(where: \.isNum)
                return .init(unchecked: String(decoding: digits, as: UTF8.self))
            }
        )
        let offset = try self.parseTimeOffset(buffer: &buffer, tracker: tracker)
        return .init(hour: hour, minute: minute, second: second, fraction: fraction, offset: offset)
    }

    // time-offset    = "Z" / time-numoffset
    // time-numoffset = ("+" / "-") time-hour ":" time-minute
    func parseTimeOffset(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> FullTime.Offset {
        func parseNumericOffset(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> (hour: Int, minute: Int) {
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            // time-hour = 00-23, time-minute = 00-59
            guard (0...23).contains(hour), (0...59).contains(minute) else {
                throw .mismatch(dynamicHint: "Invalid time offset \(hour):\(minute)")
            }
            return (hour, minute)
        }

        return try buffer.parseOneOf(
            { buffer, tracker throws(ParseFailure) -> FullTime.Offset in
                // RFC 3339 Section 5.6: `Z` may be lowercase.
                try buffer.matchFixed("Z")
                return .utc
            },
            { buffer, tracker throws(ParseFailure) -> FullTime.Offset in
                try buffer.matchFixed("+")
                let (hour, minute) = try parseNumericOffset(buffer: &buffer, tracker: tracker)
                return .plus(hour: hour, minute: minute)
            },
            { buffer, tracker throws(ParseFailure) -> FullTime.Offset in
                try buffer.matchFixed("-")
                let (hour, minute) = try parseNumericOffset(buffer: &buffer, tracker: tracker)
                return .minus(hour: hour, minute: minute)
            },
            tracker: tracker
        )
    }

    func parseLiteralSize(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        try self.parseLiteralSize(buffer: &buffer, tracker: tracker, maxLength: self.literalSizeLimit)
    }

    func parseLiteralSize(buffer: inout ParseInput, tracker: StackTracker, maxLength: Int) throws(ParseFailure) -> Int {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Int in
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
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
    func parseLiteral(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UInt8] in
            try buffer.matchFixed("{")
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.matchFixed("+")
            }
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            let bytes = try buffer.extractBytes(length: length)
            if bytes.contains(0) {
                throw .mismatch("Found NUL byte in literal")
            }
            return bytes
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    func parseLiteral8(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UInt8] in
            try buffer.matchFixed("~{")
            let length = try self.parseLiteralLength(buffer: &buffer, tracker: tracker)
            try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.matchFixed("+")
            }
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            let bytes = try buffer.extractBytes(length: length)
            if bytes.contains(0) {
                throw .mismatch("Found NUL byte in literal")
            }
            return bytes
        }
    }

    /// Parses *only* the literal size from the header, and ensures that the parsed size
    /// is within the allowed limit.
    func parseLiteralLength(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        try self.parseLiteralLength(buffer: &buffer, tracker: tracker, maxLength: self.literalSizeLimit)
    }

    /// Parses *only* the literal size from the header, and ensures that the parsed size
    /// is within the allowed limit.
    func parseLiteralLength(
        buffer: inout ParseInput,
        tracker: StackTracker,
        maxLength: Int
    ) throws(ParseFailure) -> Int {
        let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard length <= maxLength else {
            throw .literalSizeExceeded(
                ExceededLiteralSizeLimitError(
                    actualCount: length,
                    maximumCount: maxLength
                )
            )
        }
        return length
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    func parseMediaType(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Media.MediaType {
        func parseMediaTopLevel_defined(
            _ option: String,
            result: Media.TopLevelType,
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try buffer.matchFixed("\"")
            try buffer.matchFixed(option)
            try buffer.matchFixed("\"")
            return result
        }

        func parseMediaTopLevel_application(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try parseMediaTopLevel_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_audio(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try parseMediaTopLevel_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_image(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try parseMediaTopLevel_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_message(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try parseMediaTopLevel_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_video(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            try parseMediaTopLevel_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaTopLevel_other(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> Media.TopLevelType {
            let parsed = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(try decodeUTF8(parsed))
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Media.MediaType in
            let p1 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_application(buffer: &b, tracker: t)
            }
            let p2 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_audio(buffer: &b, tracker: t)
            }
            let p3 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_image(buffer: &b, tracker: t)
            }
            let p4 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_message(buffer: &b, tracker: t)
            }
            let p5 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_video(buffer: &b, tracker: t)
            }
            let p6 = ParseAlternative<Media.TopLevelType> { b, t throws(ParseFailure) in
                try parseMediaTopLevel_other(buffer: &b, tracker: t)
            }
            let topLevel = try buffer.parseOneOf([p1, p2, p3, p4, p5, p6], tracker: tracker)
            try buffer.parseSpaces()
            let sub = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.MediaType(topLevel: topLevel, sub: sub)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    func parseMediaMessage(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Media.Subtype {
        let media = try self.parseMediaType(buffer: &buffer, tracker: tracker)
        guard
            media.topLevel == .message,
            media.sub == .rfc822
        else {
            throw .mismatch("Failed to construct esearch source options")
        }
        return media.sub
    }

    // media-subtype   = string
    func parseMediaSubtype(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Media.Subtype {
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
    func parseMediaText(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Media.Subtype {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Media.Subtype in
            try buffer.matchFixed("\"TEXT\" ")
            return try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
        }
    }

    func parseMetadataOption(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MetadataOption {
        func parseMetadataOption_maxSize(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataOption {
            try buffer.matchFixed("MAXSIZE ")
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseMetadataOption_maxSize(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseMetadataOption_scope(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseMetadataOption_param(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseMetadataOptions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [MetadataOption] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("(")
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) in
                    try buffer.parseSpaces()
                    return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseMetadataResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MetadataResponse {
        func parseMetadataResponse_values(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataResponse {
            try buffer.matchFixed("METADATA ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataResponse {
            try buffer.matchFixed("METADATA ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseMetadataResponse_values(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseMetadataResponse_list(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseMetadataValue(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MetadataValue {
        func parseMetadataValue_nstring(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataValue {
            .init(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataValue_literal8(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MetadataValue {
            .init(try self.parseLiteral8(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseMetadataValue_nstring(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseMetadataValue_literal8(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseMechanismBase64(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MechanismBase64 {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> MechanismBase64 in
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UInt8] in
                try buffer.matchFixed("=")
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    func parseGmailLabel(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> GmailLabel {
        func parseGmailLabel_backslash(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> GmailLabel {
            try buffer.matchFixed("\\")
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(Array("\\\(att)".utf8))
        }

        func parseGmailLabel_string(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(raw)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseGmailLabel_backslash(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseGmailLabel_string(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    func parseNamespace(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [NamespaceDescription] {
        func parseNamespace_nil(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [NamespaceDescription] {
            try buffer.matchFixed("(")
            let descriptions = try buffer.parseOneOrMore(
                tracker: tracker,
                parser: self.parseNamespaceDescription
            )
            try buffer.matchFixed(")")
            return descriptions
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseNamespace_nil(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseNamespace_some(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    func parseNamespaceDescription(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> UInt8? {
            try buffer.matchFixed("\"")
            // QUOTED-CHAR = <any TEXT-CHAR except quoted-specials> / "\" quoted-specials
            var byte = try buffer.readByte()
            if byte == UInt8(ascii: "\\") {
                byte = try buffer.readByte()
                guard byte.isQuotedSpecial else {
                    throw .mismatch("Expected quoted special")
                }
            } else {
                guard byte.isQuotedChar else {
                    throw .mismatch("Invalid character")
                }
            }
            try buffer.matchFixed("\"")
            return byte
        }

        func parseNamespaceDescr_nil(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> UInt8? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> NamespaceDescription in
            try buffer.matchFixed("(")
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let delimiter = try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseNamespaceDescr_quotedChar(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseNamespaceDescr_nil(buffer: &b, tracker: t) },
                tracker: tracker
            )
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .init(string: string, delimiterByte: delimiter, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    func parseNamespaceResponseExtensions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> OrderedDictionary<[UInt8], [[UInt8]]> {
        var kvs = OrderedDictionary<[UInt8], [[UInt8]]>()
        try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> KeyValue<[UInt8], [[UInt8]]> in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
        return kvs
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    func parseNamespaceResponseExtension(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<[UInt8], [[UInt8]]> {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> KeyValue<[UInt8], [[UInt8]]> in
            try buffer.parseSpaces()
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> [UInt8] in
                try buffer.parseSpaces()
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .init(key: s1, value: array)
        }
    }

    // SP Namespace SP Namespace SP Namespace
    func parseNamespaceResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> NamespaceResponse {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> NamespaceResponse in
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
    func parseUIDBatchesResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> UIDBatchesResponse {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> UIDBatchesResponse in
            let correlator = try parseSearchCorrelator(buffer: &buffer, tracker: tracker)
            let batches =
                try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UIDRange] in
                    try buffer.parseSpaces()
                    return try parseUIDRangeArray(buffer: &buffer, tracker: tracker)
                } ?? []
            return UIDBatchesResponse(correlator: correlator, batches: batches)
        }
    }

    // nil             = "NIL"
    func parseNil(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
        try buffer.matchFixed("nil")
    }

    // nstring         = string / nil
    func parseNString(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8]? {
        func parseNString_nil(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8]? {
            try buffer.matchFixed("NIL")
            return nil
        }

        func parseNString_some(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8]? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseNString_nil(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseNString_some(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // number          = 1*DIGIT
    func parseNumber(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        let (num, _) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    func parseNZNumber(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        try buffer.parseUnsignedInteger(tracker: tracker).number
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    func parseOptionExtension(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<OptionExtensionKind, OptionValueComp?> {
        func parseOptionExtensionKind_standard(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OptionExtensionKind {
            .standard(.init(unchecked: try self.parseAtom(buffer: &buffer, tracker: tracker)))
        }

        func parseOptionExtensionKind_vendor(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try buffer.composite(tracker: tracker) {
            buffer,
            tracker throws(ParseFailure) -> KeyValue<OptionExtensionKind, OptionValueComp?> in
            let type = try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseOptionExtensionKind_standard(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseOptionExtensionKind_vendor(buffer: &b, tracker: t) },
                tracker: tracker
            )
            let value = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> OptionValueComp in
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
    func parseOptionValueComp(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> OptionValueComp {
        let elements = try self.parseOptionValueCompSequence(buffer: &buffer, tracker: tracker)
        guard elements.count == 1 else { return .array(elements) }
        return elements[0]
    }

    private func parseOptionValueCompSequence(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [OptionValueComp] {
        func parseElement_string(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseElement_parenthesized(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> OptionValueComp {
            try buffer.matchFixed("(")
            let elements = try self.parseOptionValueCompSequence(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .array(elements)
        }

        func parseElement(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> OptionValueComp {
            try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseElement_string(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseElement_parenthesized(buffer: &b, tracker: t) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            var elements = [try parseElement(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &elements, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> OptionValueComp in
                try buffer.parseSpaces()
                return try parseElement(buffer: &buffer, tracker: tracker)
            }
            return elements
        }
    }

    // option-value =  "(" option-val-comp ")"
    func parseOptionValue(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> OptionValueComp {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> OptionValueComp in
            try buffer.matchFixed("(")
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    func parseOptionVendorTag(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> OptionExtensionKind.Vendor {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> OptionExtensionKind.Vendor in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(unchecked: "\(token)-\(atom)")
        }
    }

    // partial         = "<" number "." nz-number ">"
    func parsePartial(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ClosedRange<UInt32> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> ClosedRange<UInt32> in
            try buffer.matchFixed("<")
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw .mismatch("Partial range start is invalid.")
            }
            try buffer.matchFixed(".")
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw .mismatch("Partial range count is invalid.")
            }
            guard num2 > 0 else { throw .mismatch(dynamicHint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try buffer.matchFixed(">")
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw .mismatch(dynamicHint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw .mismatch(dynamicHint: "Range is invalid: <\(num1).\(num2)>.") }
            return num1...upper2.partialValue
        }
    }

    func parseByteRange(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ByteRange {
        func parseByteRange_length(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
            try buffer.matchFixed(".")
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> ByteRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try buffer.parseOptional(tracker: tracker) { b, t throws(ParseFailure) in
                try parseByteRange_length(buffer: &b, tracker: t)
            }
            return .init(offset: offset, length: length)
        }
    }

    // password        = astring
    func parsePassword(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        let bytes = try self.parseAString(buffer: &buffer, tracker: tracker)
        return String(decoding: bytes, as: UTF8.self)
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    func parsePatterns(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [[UInt8]] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [[UInt8]] in
            try buffer.matchFixed("(")
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> [UInt8] in
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
    func parseQuoted(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [UInt8] in
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
            var unescaped: [UInt8] = []
            unescaped.reserveCapacity(data.count)
            var index = data.startIndex
            while index < data.endIndex {
                let next = data[index]
                index += 1
                guard next == UInt8(ascii: "\\") else {
                    unescaped.append(next)
                    continue
                }
                guard index < data.endIndex, data[index].isQuotedSpecial else {
                    throw .mismatch(
                        dynamicHint:
                            "Invalid escape in quoted string '\(String(decoding: data, as: Unicode.UTF8.self))'"
                    )
                }
                unescaped.append(data[index])
                index += 1
            }
            return unescaped
        }
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    func parseReturnOption(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ReturnOption {
        func parseReturnOption_subscribed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ReturnOption {
            try buffer.matchFixed("SUBSCRIBED")
            return .subscribed
        }

        func parseReturnOption_children(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ReturnOption {
            try buffer.matchFixed("CHILDREN")
            return .children
        }

        func parseReturnOption_statusOption(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_objectID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ReturnOption {
            try buffer.matchFixed("OBJECTID")
            return .objectID
        }

        func parseReturnOption_optionExtension(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        let p1 = ParseAlternative<ReturnOption> { b, t throws(ParseFailure) in
            try parseReturnOption_subscribed(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<ReturnOption> { b, t throws(ParseFailure) in
            try parseReturnOption_children(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<ReturnOption> { b, t throws(ParseFailure) in
            try parseReturnOption_statusOption(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<ReturnOption> { b, t throws(ParseFailure) in
            try parseReturnOption_objectID(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<ReturnOption> { b, t throws(ParseFailure) in
            try parseReturnOption_optionExtension(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5], tracker: tracker)
    }

    func parseScopeOption(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ScopeOption {
        func parseScopeOption_zero(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ScopeOption {
            try buffer.matchFixed("0")
            return .zero
        }

        func parseScopeOption_one(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ScopeOption {
            try buffer.matchFixed("1")
            return .one
        }

        func parseScopeOption_infinity(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ScopeOption {
            try buffer.matchFixed("infinity")
            return .infinity
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("DEPTH ")
            return try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseScopeOption_zero(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseScopeOption_one(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseScopeOption_infinity(buffer: &b, tracker: t) },
                tracker: tracker
            )
        }
    }

    // section         = "[" [section-spec] "]"
    func parseSection(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SectionSpecifier {
        func parseSection_none(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> SectionSpecifier in
                try buffer.matchFixed("[]")
                return .complete
            }
        }

        func parseSection_some(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier {
            try buffer.matchFixed("[")
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("]")
            return spec
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseSection_none(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseSection_some(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // section-binary  = "[" [section-part] "]"
    func parseSectionBinary(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SectionSpecifier.Part {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> SectionSpecifier.Part in
            try buffer.matchFixed("[")
            let part = try buffer.parseOptional(tracker: tracker, parser: self.parseSectionPart)
            try buffer.matchFixed("]")
            return part ?? .init([])
        }
    }

    // section-part    = nz-number *("." nz-number)
    func parseSectionPart(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SectionSpecifier.Part {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> Int in
                try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> Int in
                    try buffer.matchFixed(".")
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    func parseSectionSpecifier(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SectionSpecifier {
        func parseSectionSpecifier_noPart(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier {
            try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> SectionSpecifier in
                let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
                guard kind != .MIMEHeader else {
                    throw .mismatch("Cannot use MIME with an empty section part")
                }
                return .init(kind: kind)
            }
        }

        func parseSectionSpecifier_withPart(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind =
                try buffer.parseOptional(tracker: tracker) {
                    (buffer, tracker) throws(ParseFailure) -> SectionSpecifier.Kind in
                    try buffer.matchFixed(".")
                    return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
                } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseSectionSpecifier_withPart(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseSectionSpecifier_noPart(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // section-text    = section-msgtext / "MIME"
    func parseSectionSpecifierKind(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            try buffer.matchFixed("MIME")
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER")
            return .header
        }

        func parseSectionSpecifierKind_headerFields(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER.FIELDS ")
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            try buffer.matchFixed("HEADER.FIELDS.NOT ")
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            try buffer.matchFixed("TEXT")
            return .text
        }

        func parseSectionSpecifierKind_complete(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SectionSpecifier.Kind {
            .complete
        }

        let p1 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_mime(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_headerFields(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_notHeaderFields(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_header(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_text(buffer: &b, tracker: t)
        }
        let p6 = ParseAlternative<SectionSpecifier.Kind> { b, t throws(ParseFailure) in
            try parseSectionSpecifierKind_complete(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5, p6], tracker: tracker)
    }

    func parseSelectParameter(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SelectParameter {
        func parseSelectParameter_basic(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SelectParameter {
            try buffer.matchFixed("CONDSTORE")
            return .condStore
        }

        func parseSelectParameter_qresync(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SelectParameter {
            try buffer.matchFixed("QRESYNC (")
            let uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUIDs = try buffer.parseOptional(
                tracker: tracker,
                parser: { (buffer, tracker) throws(ParseFailure) -> UIDSet in
                    try buffer.parseSpaces()
                    return try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                }
            )
            let seqMatchData = try buffer.parseOptional(
                tracker: tracker,
                parser: { (buffer, tracker) throws(ParseFailure) -> SequenceMatchData in
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

        func parseSelectParameter_objectID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SelectParameter {
            try buffer.matchFixed("OBJECTID")
            let compound = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> CompoundObjectID in
                try buffer.parseSpaces()
                return try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker)
            }
            return .objectID(compound)
        }

        let p1 = ParseAlternative<SelectParameter> { b, t throws(ParseFailure) in
            try parseSelectParameter_objectID(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<SelectParameter> { b, t throws(ParseFailure) in
            try parseSelectParameter_qresync(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<SelectParameter> { b, t throws(ParseFailure) in
            try parseSelectParameter_condstore(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<SelectParameter> { b, t throws(ParseFailure) in
            try parseSelectParameter_basic(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4], tracker: tracker)
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    func parseParameters<Kind>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> OrderedDictionary<ExtensionKey<Kind>, ParameterValue?> {
        try buffer.composite(tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> OrderedDictionary<ExtensionKey<Kind>, ParameterValue?> in
            try buffer.matchFixed(" (")
            var kvs = OrderedDictionary<ExtensionKey<Kind>, ParameterValue?>()
            let param: KeyValue<ExtensionKey<Kind>, ParameterValue?> =
                try self.parseParameter(buffer: &buffer, tracker: tracker)
            kvs[param.key] = param.value
            try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> KeyValue<ExtensionKey<Kind>, ParameterValue?> in
                try buffer.parseSpaces()
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return kvs
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    func parseStatusAttribute(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MailboxAttribute {
        let parsed = try buffer.parseOneOrMoreCharacters { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        let string = try decodeUTF8(parsed)
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw .mismatch(dynamicHint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    func parseStatusOption(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [MailboxAttribute] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> [MailboxAttribute] in
            try buffer.matchFixed("STATUS (")
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> MailboxAttribute in
                try buffer.parseSpaces()
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseStoreModifiers(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [StoreModifier] {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { (buffer, tracker) throws(ParseFailure) in
                    try buffer.parseSpaces()
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        }
    }

    func parseStoreModifier(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreModifier {
        func parseFetchModifier_unchangedSince(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> StoreModifier {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseFetchModifier_unchangedSince(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseFetchModifier_other(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    func parseStoreOperation(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreOperation {
        try buffer.parseOneOf(
            { (buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreOperation in
                try buffer.matchFixed("+")
                return .add
            },
            { (buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreOperation in
                try buffer.matchFixed("-")
                return .remove
            },
            { (buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreOperation in
                try buffer.matchFixed("")
                return .replace
            },
            tracker: tracker
        )
    }

    func parseStoreSilent(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Bool {
        do {
            try buffer.matchFixed(".SILENT")
            return true
        } catch .mismatch {
            return false
        }
    }

    func parseStoreGmailLabels(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> StoreGmailLabels {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("X-GM-LABELS", leadingSpaces: .rejected)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" (")
            var labels = [try self.parseGmailLabel(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &labels, tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
                return try self.parseGmailLabel(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .init(operation: operation, silent: silent, gmailLabels: labels)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    func parseStoreFlags(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreFlags {
        func parseStoreFlags_array(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [Flag] {
            var flags = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &flags, tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
                return try self.parseFlag(buffer: &buffer, tracker: tracker)
            }
            return flags
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> StoreFlags in
            let operation = try self.parseStoreOperation(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("FLAGS", leadingSpaces: .rejected)
            let silent = try self.parseStoreSilent(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let p1 = ParseAlternative<[Flag]> { b, t throws(ParseFailure) in
                try parseStoreFlags_array(buffer: &b, tracker: t)
            }
            let flagList = ParseAlternative<[Flag]> { b, t throws(ParseFailure) in
                try self.parseFlagList(buffer: &b, tracker: t)
            }
            let flags = try buffer.parseOneOf([flagList, p1], tracker: tracker)
            return .init(operation: operation, silent: silent, flags: flags)
        }
    }

    func parseStoreData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreData {
        try buffer.parseOneOf(
            { (buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreData in
                let data = try self.parseStoreGmailLabels(buffer: &buffer, tracker: tracker)
                return .gmailLabels(data)
            },
            { (buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> StoreData in
                let data = try self.parseStoreFlags(buffer: &buffer, tracker: tracker)
                return .flags(data)
            },
            tracker: tracker
        )
    }

    // string          = quoted / literal
    //
    // Spelled out rather than `buffer.parseOneOf(self.parseQuoted, self.parseLiteral, ...)`, because
    // `self.parseQuoted` as a *value* is a partial application that heap-allocates a context holding a
    // copy of the `GrammarParser`. Two per call, on one of the most-called productions in the grammar:
    // 142 allocations per `BODYSTRUCTURE` message. Calling the two alternatives directly forms no
    // closure at all.
    func parseString(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        do {
            return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try self.parseQuoted(buffer: &buffer, tracker: tracker)
            }
        } catch .mismatch, .badCommand {
            // Try the literal form.
        }
        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try self.parseLiteral(buffer: &buffer, tracker: tracker)
        }
    }

    /// Variant of `parseString()` allowing non-ASCII inside quoted strings.
    ///
    /// Not allowed by RFC 3501, but some emails have non-ASCII headers, and some servers
    /// end up copying the non-ASCII values into, for example, `BODYSTRUCTURE` parameters.
    func parseStringAllowingNonASCII(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try self.parseString(buffer: &buffer, tracker: tracker)
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    func parseTag(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command.Tag {
        let parsed = try buffer.parseOneOrMoreCharacters { $0.isTagChar }
        return Command.Tag(unchecked: try decodeUTF8(parsed))
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    func parseTaggedExtension<Kind>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<ExtensionKey<Kind>, ParameterValue> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let key: ExtensionKey<Kind> = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if String(key).lowercased() == "catenate" {
                throw .mismatch("catenate extension")
            }

            try buffer.parseSpaces()
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    func parseParameterName<Kind>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ExtensionKey<Kind> {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> ExtensionKey<Kind> in

            let fchar = try buffer.readByte()
            guard fchar.isTaggedLabelFchar else {
                throw .mismatch(dynamicHint: "\(fchar) is not a valid fchar")
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
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) {
        while true {
            let mark = buffer.consumed
            do {
                try buffer.parseSpaces()
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch .mismatch {
                return
            }
            try buffer.requireProgress(since: mark)
        }
    }

    func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) {
            let parsed = try self.parseAString(buffer: &buffer, tracker: tracker)
            into.append(try decodeUTF8(parsed))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) {
            try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.matchFixed("(")
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(")")
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let save = buffer
            // `do` inside a closure doesn't infer typed throws; annotate it.
            do throws(ParseFailure) {
                try parseTaggedExtensionComplex_string(into: &into, buffer: &buffer, tracker: tracker)
            } catch .mismatch {
                // Only a mismatch means "try the bracketed form"; an astring never starts with `(`.
                buffer = save
                try parseTaggedExtensionComplex_bracketed(into: &into, buffer: &buffer, tracker: tracker)
            }
        }
    }

    // NOTE: Left-recursive, modification above, this needs some work
    // tagged-ext-comp     = astring /
    //                       tagged-ext-comp *(SP tagged-ext-comp) /
    //                       "(" tagged-ext-comp ")"
    func parseTaggedExtensionComplex(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    func parseParameterValue(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ParameterValue {
        func parseTaggedExtensionSimple_set(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ParameterValue {
            .sequence(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ParameterValue {
            try buffer.matchFixed("(")
            let comp =
                try buffer.parseOptional(tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try buffer.matchFixed(")")
            return .comp(comp)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseTaggedExtensionSimple_set(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseTaggedExtensionVal_comp(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // text            = 1*TEXT-CHAR
    func parseText(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [UInt8] {
        try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isTextChar
        }
    }

    // mechanism = "INTERNAL" / 1*(ALPHA / DIGIT / "-" / ".")
    func parseUAuthMechanism(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> URLAuthenticationMechanism {
        let parsed = try buffer.parseOneOrMoreCharacters { $0.isMechanismChar }
        return URLAuthenticationMechanism(unchecked: try decodeUTF8(parsed))
    }

    // userid          = astring
    func parseUserId(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        let astring = try self.parseAString(buffer: &buffer, tracker: tracker)
        return String(decoding: astring, as: UTF8.self)
    }

    // vendor-token     = atom (maybe?!?!?!)
    func parseVendorToken(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> String {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            char.isAlpha
        }
        return try decodeUTF8(parsed)
    }

    // resource-name     = "STORAGE" / "MESSAGE" / "MAILBOX" /
    //                     "ANNOTATION-STORAGE" / resource-name-ext
    // resource-name-ext = atom
    func parseQuotaResourceName(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> QuotaResource.Name {
        // An atom is exactly what a `Name` requires.
        QuotaResource.Name(unchecked: try parseAtom(buffer: &buffer, tracker: tracker))
    }

    // setquota_list   ::= "(" 0#setquota_resource ")"
    func parseQuotaLimits(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [QuotaLimit] {
        // setquota_resource ::= atom SP number
        func parseQuotaLimit(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> QuotaLimit {
            try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                try buffer.parseOptional(
                    tracker: tracker,
                    parser: { input, _ throws(ParseFailure) in try input.parseSpaces() }
                )
                let resourceName = try parseQuotaResourceName(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaLimit(resourceName: resourceName, limit: limit)
            }
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> [QuotaLimit] in
            try buffer.matchFixed("(")
            let limits = try buffer.parseZeroOrMore(tracker: tracker) { b, t throws(ParseFailure) in
                try parseQuotaLimit(buffer: &b, tracker: t)
            }
            try buffer.matchFixed(")")
            return limits
        }
    }

    func parseQuotaRoot(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> QuotaRoot {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return QuotaRoot(string)
    }

    // RFC 5465
    // one-or-more-mailbox = mailbox / many-mailboxes
    func parseOneOrMoreMailbox(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Mailboxes {
        // many-mailboxes  = "(" mailbox *(SP mailbox) ")
        func parseManyMailboxes(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Mailboxes {
            try buffer.matchFixed("(")
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while true {
                let mark = buffer.consumed
                guard
                    try buffer.parseOptional(
                        tracker: tracker,
                        parser: { input, _ throws(ParseFailure) in try input.parseSpaces() }
                    ) != nil
                else { break }
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
                try buffer.requireProgress(since: mark)
            }
            try buffer.matchFixed(")")
            guard let returnValue = Mailboxes(mailboxes) else {
                throw .mismatch("Failed to unwrap mailboxes which should be impossible")
            }
            return returnValue
        }

        func parseSingleMailboxes(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Mailboxes {
            let mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            guard let returnValue = Mailboxes(mailboxes) else {
                throw .mismatch("Failed to unwrap single mailboxes which should be impossible")
            }
            return returnValue
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseManyMailboxes(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseSingleMailboxes(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    func parseFilterMailboxes(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("selected")
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("selected-delayed")
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("inboxes")
            return .inboxes
        }

        func parseFilterMailboxes_Personal(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("personal")
            return .personal
        }

        func parseFilterMailboxes_Subscribed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("subscribed")
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("subtree ")
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("mailboxes ")
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 7377
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.matchFixed("subtree-one ")
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        let p1 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_SelectedDelayed(buffer: &b, tracker: t)
        }
        let p2 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_SubtreeOne(buffer: &b, tracker: t)
        }
        let p3 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Selected(buffer: &b, tracker: t)
        }
        let p4 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Inboxes(buffer: &b, tracker: t)
        }
        let p5 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Personal(buffer: &b, tracker: t)
        }
        let p6 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Subscribed(buffer: &b, tracker: t)
        }
        let p7 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Subtree(buffer: &b, tracker: t)
        }
        let p8 = ParseAlternative<MailboxFilter> { b, t throws(ParseFailure) in
            try parseFilterMailboxes_Mailboxes(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([p1, p2, p3, p4, p5, p6, p7, p8], tracker: tracker)
    }

    // RFC 7377
    // scope-options =  scope-option *(SP scope-option)
    func parseExtendedSearchScopeOptions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ExtendedSearchScopeOptions {
        var options = OrderedDictionary<ExtensionKey<ExtendedSearchScopeOptions>, ParameterValue?>()
        while true {
            let mark = buffer.consumed
            let param: KeyValue<ExtensionKey<ExtendedSearchScopeOptions>, ParameterValue?> =
                try parseParameter(buffer: &buffer, tracker: tracker)
            options[param.key] = param.value
            try buffer.requireProgress(since: mark)
            guard
                try buffer.parseOptional(
                    tracker: tracker,
                    parser: { input, _ throws(ParseFailure) in try input.parseSpaces() }
                ) != nil
            else { break }
        }
        guard let returnValue = ExtendedSearchScopeOptions(options) else {
            throw .mismatch("Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
        return returnValue
    }

    // RFC 7377
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    func parseExtendedSearchSourceOptions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ExtendedSearchSourceOptions {
        func parseExtendedSearchSourceOptions_spaceFilter(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MailboxFilter {
            try buffer.parseSpaces()
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseExtendedSearchSourceOptions_sourceMBox(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> [MailboxFilter] {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            try buffer.forEachRepetition(
                tracker: tracker,
                parser: { b, t throws(ParseFailure) in
                    try parseExtendedSearchSourceOptions_spaceFilter(buffer: &b, tracker: t)
                },
                { sources.append($0) }
            )
            return sources
        }

        func parseExtendedSearchSourceOptions_scopeOptions(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ExtendedSearchScopeOptions {
            try buffer.matchFixed(" (")
            let result = try parseExtendedSearchScopeOptions(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return result
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("IN (")
            let sourceMbox = try parseExtendedSearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try buffer.parseOptional(
                tracker: tracker,
                parser: { b, t throws(ParseFailure) in
                    try parseExtendedSearchSourceOptions_scopeOptions(buffer: &b, tracker: t)
                }
            )
            try buffer.matchFixed(")")
            guard let result = ExtendedSearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) else {
                throw .mismatch("Failed to construct esearch source options")
            }
            return result
        }
    }

    // RFC 7377
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    // Ignoring the command here.
    func parseExtendedSearchOptions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ExtendedSearchOptions {
        func parseExtendedSearchOptions_sourceOptions(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ExtendedSearchSourceOptions {
            try buffer.parseSpaces()
            let result = try parseExtendedSearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try buffer.parseOptional(
            tracker: tracker,
            parser: { b, t throws(ParseFailure) in try parseExtendedSearchOptions_sourceOptions(buffer: &b, tracker: t)
            }
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
    func parseObjectID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ObjectID {
        let parsed = try buffer.parseZeroOrMoreCharacters { char -> Bool in
            char.isObjectIDChar
        }
        let string = try decodeUTF8(parsed)
        guard let objectID = ObjectID(string) else {
            throw .mismatch("Invalid object ID.")
        }
        return objectID
    }

    // OBJECTID+
    // objectid-key = "MAILBOXID" / "ACCOUNTID" / "EMAILID" / "THREADID" / atom
    // objectid-kvpair = objectid-key SP objectid
    // objectid-compound = "OBJECTID" SP "(" [objectid-kvpair *(SP objectid-kvpair)] ")"
    func parseCompoundObjectID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CompoundObjectID
    {
        enum Pair {
            case mailboxID(MailboxID)
            case accountID(AccountID)
            case emailID(EmailID)
            case threadID(ThreadID)
            case unknown
        }

        func parsePair_mailboxID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            try buffer.matchFixed("MAILBOXID ")
            return .mailboxID(MailboxID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_accountID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            try buffer.matchFixed("ACCOUNTID ")
            return .accountID(AccountID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_emailID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            try buffer.matchFixed("EMAILID ")
            return .emailID(EmailID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        func parsePair_threadID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            try buffer.matchFixed("THREADID ")
            return .threadID(ThreadID(try self.parseObjectID(buffer: &buffer, tracker: tracker)))
        }

        // Unrecognized keys, and their values, are parsed and discarded. Clients MUST ignore
        // unrecognized key-value pairs so that future extensions can add new identifier types.
        func parsePair_unknown(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            _ = try self.parseAtom(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            _ = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .unknown
        }

        func parsePair(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Pair {
            let p1 = ParseAlternative<Pair> { b, t throws(ParseFailure) in
                try parsePair_mailboxID(buffer: &b, tracker: t)
            }
            let p2 = ParseAlternative<Pair> { b, t throws(ParseFailure) in
                try parsePair_accountID(buffer: &b, tracker: t)
            }
            let p3 = ParseAlternative<Pair> { b, t throws(ParseFailure) in
                try parsePair_emailID(buffer: &b, tracker: t)
            }
            let p4 = ParseAlternative<Pair> { b, t throws(ParseFailure) in
                try parsePair_threadID(buffer: &b, tracker: t)
            }
            let p5 = ParseAlternative<Pair> { b, t throws(ParseFailure) in
                try parsePair_unknown(buffer: &b, tracker: t)
            }
            return try buffer.parseOneOf([p1, p2, p3, p4, p5], tracker: tracker)
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> CompoundObjectID in
            try buffer.matchFixed("(")

            var pairs: [Pair] = []
            if let first = try buffer.parseOptional(
                tracker: tracker,
                parser: { b, t throws(ParseFailure) in try parsePair(buffer: &b, tracker: t) }
            ) {
                pairs.append(first)
                try buffer.parseZeroOrMore(into: &pairs, tracker: tracker) {
                    (buffer, tracker) throws(ParseFailure) -> Pair in
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
    func parseObjectIDLeniently(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ObjectID? {
        let parsed = try buffer.parseZeroOrMoreCharacters { char -> Bool in
            switch char {
            case UInt8(ascii: " "), UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "\r"), UInt8(ascii: "\n"):
                return false
            default:
                return true
            }
        }
        // Non-UTF-8 bytes become U+FFFD, which isn't a valid object ID character.
        return ObjectID(String(decoding: parsed, as: UTF8.self))
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    func parse2Digit(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    func parse4Digit(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    func parseNDigits(buffer: inout ParseInput, tracker: StackTracker, bytes: Int) throws(ParseFailure) -> Int {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let (num, size) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
            guard size == bytes else {
                throw .mismatch(expectedDigits: bytes, got: size)
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

    mutating func newStackFrame() throws(ParseFailure) {
        self.stackDepth += 1
        guard self.stackDepth < self.maximumStackDepth else {
            throw .tooMuchRecursion(TooMuchRecursion(limit: self.maximumStackDepth))
        }
    }
}
