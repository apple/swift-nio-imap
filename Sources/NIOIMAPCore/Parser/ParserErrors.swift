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

/// Decodes `bytes` as UTF-8.
///
/// A free function rather than a `String` initialiser because it throws a ``ParserError`` carrying the
/// source location that asked for the decode, which is what the grammar wants and what a general-purpose
/// initialiser has no business reporting.
///
/// - Throws: ``ParseFailure/mismatch(_:)`` when `bytes` are not valid UTF-8.
func decodeUTF8(
    _ bytes: some Collection<UInt8>,
    file: StaticString = #fileID,
    line: Int = #line
) throws(ParseFailure) -> String {
    guard let string = String(validatingUTF8Bytes: bytes) else {
        throw .mismatch(.invalidUTF8(file: file, line: line))
    }
    return string
}

/// What the parser's internals throw: every parser error, under one concrete type.
///
/// Typed throws, because an untyped `throw` boxes its error on the heap, and the parser throws as control
/// flow — every alternative of every `parseOneOf` that does not match. A `throws(ParseFailure)` function
/// returns this in registers, so a failed match costs no allocation. Only ``other(_:)``, ``badCommand(_:)``
/// and a `dynamicHint:` mismatch allocate.
///
/// Registers only while it is at most 4 words; at 64 bytes it went through a hidden out-pointer and
/// doubled debug stack use per nesting level. Hence the compact payloads (``ParserError``,
/// ``NoForwardProgress``) and the `indirect` ``badCommand(_:)``. A test pins the size.
///
/// Throw a mismatch with ``mismatch(_:file:line:)``, which records the throwing site:
/// `throw .mismatch("Expected digit")`, or `throw .mismatch(dynamicHint: "Got \(byte)")` (allocates).
///
/// Internal only. The public entry points convert back with ``unwrapped`` so callers see today's
/// public error types.
///
/// ```
///  grammar / combinators ── throws(ParseFailure) ──▶ entry point ── unwrapped ──▶ public `throws`
///         ▲
///         └── ParseFailure(error) ◀── untyped API (MailboxPath, ModifiedUTF7, …)
/// ```
enum ParseFailure: Error {
    /// The input does not match this production. Backtracking points (``ParseInput/parseOptional(tracker:parser:)``,
    /// ``ParseInput/parseOneOf(_:tracker:file:line:)``) absorb it.
    case mismatch(ParserError)
    /// A tagged command failed to parse. ``ParseInput/parseOneOf(_:tracker:file:line:)`` absorbs it, as
    /// it did ``BadCommand`` before typed throws.
    ///
    /// `indirect`: ``BadCommand`` is 40 bytes and would push `ParseFailure` out of registers. One allocation
    /// per bad command.
    indirect case badCommand(BadCommand)
    /// More bytes are needed. Never absorbed by a backtracking point; becomes ``IncompleteMessage``.
    case incomplete
    case noForwardProgress(NoForwardProgress)
    case tooMuchRecursion(TooMuchRecursion)
    case literalSizeExceeded(ExceededLiteralSizeLimitError)
    case messageAttributesExceeded(ExceededMaximumMessageAttributesError)
    case bodySizeExceeded(ExceededMaximumBodySizeError)
    /// An error from an untyped API the grammar calls (`MailboxPath.init`, `ModifiedUTF7.decode`). Boxed;
    /// cold paths only.
    case other(any Error)

    /// A mismatch with a literal hint, located at the caller. No allocation.
    static func mismatch(
        _ hint: StaticString = "Unknown",
        file: StaticString = #fileID,
        line: Int = #line
    ) -> Self {
        .mismatch(ParserError(hint: hint, file: file, line: line))
    }

    /// `"Expected \(expected) digits, got \(got)"`, located at the caller. Formatted when read, so no
    /// allocation: `parseDateDayFixed` throws it on every 2-digit day.
    static func mismatch(
        expectedDigits expected: Int,
        got: Int,
        file: StaticString = #fileID,
        line: Int = #line
    ) -> Self {
        .mismatch(ParserError(expectedDigits: expected, got: got, file: file, line: line))
    }

    /// A mismatch with a computed hint, located at the caller. Allocates; cold paths only.
    static func mismatch(dynamicHint: String, file: StaticString = #fileID, line: Int = #line) -> Self {
        .mismatch(ParserError(dynamicHint: dynamicHint, file: file, line: line))
    }

    /// Classifies an untyped error, so that a known type keeps its meaning — a ``ParserError`` from an
    /// untyped callee must still backtrack.
    init(_ error: any Error) {
        switch error {
        case let failure as ParseFailure: self = failure
        case let error as ParserError: self = .mismatch(error)
        case let error as BadCommand: self = .badCommand(error)
        case is IncompleteMessage: self = .incomplete
        case let error as NoForwardProgress: self = .noForwardProgress(error)
        case let error as TooMuchRecursion: self = .tooMuchRecursion(error)
        case let error as ExceededLiteralSizeLimitError: self = .literalSizeExceeded(error)
        case let error as ExceededMaximumMessageAttributesError: self = .messageAttributesExceeded(error)
        case let error as ExceededMaximumBodySizeError: self = .bodySizeExceeded(error)
        default: self = .other(error)
        }
    }

    /// The public error this stands for. Boxes; call once, where an error leaves the parser.
    var unwrapped: any Error {
        switch self {
        case .mismatch(let error): error
        case .badCommand(let error): error
        case .incomplete: IncompleteMessage()
        case .noForwardProgress(let error): error
        case .tooMuchRecursion(let error): error
        case .literalSizeExceeded(let error): error
        case .messageAttributesExceeded(let error): error
        case .bodySizeExceeded(let error): error
        case .other(let error): error
        }
    }
}

/// The parser needs more bytes before it can decide.
///
/// Thrown, rather than returned, because it can arise anywhere in the grammar; the entry points turn
/// it back into "no message yet".
struct IncompleteMessage: Error {
    internal init() {}
}

/// Parsing a tagged command failed. Includes the tag of the invalid command, and the parsing error.
///
/// When the server receives a command from a client, it includes a tag for correlation.
/// If the command line cannot be parsed, this error includes both the tag (so the server
/// can send back a properly-tagged error response) and details about what went wrong.
///
/// - SeeAlso: ``ParserError``, [RFC 3501 Section 6.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.1)
public struct BadCommand: Error {
    /// The tag of the bad command.
    ///
    /// Allows the server to send a properly-tagged error response to the client,
    /// maintaining IMAP's request/response correlation even when the command is malformed.
    public var commandTag: Command.Tag

    /// Why parsing failed.
    ///
    /// Contains a human-readable hint about the parsing error and source location information.
    public var parserError: ParserError
}

/// An error occurred when parsing an IMAP command or response.
///
/// `ParserError` is thrown when the IMAP protocol parser encounters bytes that cannot be
/// interpreted according to the IMAP grammar (RFC 3501 or extensions). Common causes include:
/// - Invalid UTF-8 sequences in string fields
/// - Malformed protocol syntax (for example, unexpected characters or missing required elements)
/// - Non-conforming protocol elements
///
/// The ``hint`` field provides a developer-friendly description of what went wrong.
/// The internal file and line information is useful for debugging parser issues.
///
/// - SeeAlso: [RFC 3501 Section 4](https://datatracker.ietf.org/doc/html/rfc3501#section-4) (grammar)
public struct ParserError: Error {
    /// 24 bytes, so that ``ParseFailure`` fits in registers (see `ParseFailure`'s size test). A `String`
    /// hint plus a `StaticString` file plus an `Int` line would be 48.
    ///
    /// ```
    /// literal:  [ hint pointer | file pointer | line u32, file len u8, isASCII, hint len u16 ]
    /// digits:   [ file pointer | line u32, file len u8, -, expected u16 | got u32 ]
    /// boxed:    [ InterpolatedHint ─▶ { hint: String, site } ]
    /// ```
    private enum Storage {
        /// Hot: the hint is a string literal. No allocation.
        case literal(LiteralHint)
        /// Hot: a digit-count mismatch, formatted when read. No allocation.
        case digitCount(DigitCountHint)
        /// Cold: an interpolated hint, or one assigned through ``hint``.
        case boxed(InterpolatedHint)
    }

    private var storage: Storage

    static func invalidUTF8(file: StaticString = #fileID, line: Int = #line) -> Self {
        ParserError(hint: "Invalid UTF8", file: file, line: line)
    }

    /// If possible, a description of the error and why it occurred.
    ///
    /// Describes the parsing failure in human-readable terms, such as
    /// "Invalid UTF8", "Missing CRLF", "Unexpected character", etc. It's intended
    /// for logging and debugging purposes.
    ///
    /// - Note: These errors are thrown as part of ordinary control flow — `parseOneOf` throws one
    ///     for every alternative that doesn't match. So the parser takes the hint as a `StaticString`
    ///     and keeps only a pointer to the literal: throwing costs no allocation, and the compiler rejects
    ///     an interpolated hint. Interpolation needs the explicit `dynamicHint:` spelling, which boxes;
    ///     keep it off paths that are taken often.
    public var hint: String {
        get {
            switch storage {
            case .literal(let literal): literal.hint
            case .digitCount(let digits): digits.hint
            case .boxed(let boxed): boxed.hint
            }
        }
        set {
            storage = .boxed(InterpolatedHint(hint: newValue, site: site))
        }
    }

    /// Where the error was thrown.
    private var site: ThrowSite {
        switch storage {
        case .literal(let literal): literal.site
        case .digitCount(let digits): digits.site
        case .boxed(let boxed): boxed.site
        }
    }

    /// The `#fileID` of the throwing site.
    var file: String { site.file }
    /// The `#line` of the throwing site.
    var line: Int { site.line }

    /// A literal hint: no allocation, unless the literal is too long to point at (then boxed).
    init(hint: StaticString = "Unknown", file: StaticString = #fileID, line: Int = #line) {
        let site = ThrowSite(file: file, line: line)
        guard let literal = LiteralHint(hint, site: site) else {
            self.storage = .boxed(InterpolatedHint(hint: "\(hint)", site: site))
            return
        }
        self.storage = .literal(literal)
    }

    /// `"Expected \(expected) digits, got \(got)"`, without allocating.
    init(expectedDigits expected: Int, got: Int, file: StaticString = #fileID, line: Int = #line) {
        let site = ThrowSite(file: file, line: line)
        self.storage = .digitCount(DigitCountHint(expected: expected, got: got, site: site))
    }

    /// A computed hint. Allocates; cold paths only.
    init(dynamicHint: String, file: StaticString = #fileID, line: Int = #line) {
        self.storage = .boxed(InterpolatedHint(hint: dynamicHint, site: ThrowSite(file: file, line: line)))
    }
}

extension ParserError: CustomReflectable {
    /// The fields it printed with before its storage went compact, rather than raw pointers:
    /// `ParserError(hint: "Expected digit", file: "NIOIMAPCore/Foo.swift", line: 42)`.
    public var customMirror: Mirror {
        Mirror(self, children: ["hint": hint, "file": file, "line": line], displayStyle: .struct)
    }
}

/// A `#fileID` / `#line` pair in 13 bytes; `StaticString` plus `Int` is 32.
///
/// Points at the literal, so it costs nothing to make. Converted to `String` only when read.
struct ThrowSite: @unchecked Sendable {  // @unchecked: points at an immutable string literal.
    /// Stands in for a file that is not a pointer-backed literal (never the case for `#fileID`).
    private static let unknownFile: StaticString = "<unknown>"

    private var fileStart: UnsafeRawPointer
    private var lineNumber: UInt32
    /// `#fileID` is `Module/File.swift`; anything longer is truncated.
    private var fileLength: UInt8

    init(file: StaticString, line: Int) {
        let file = file.hasPointerRepresentation ? file : Self.unknownFile
        self.fileStart = UnsafeRawPointer(file.utf8Start)
        self.fileLength = UInt8(clamping: file.utf8CodeUnitCount)
        self.lineNumber = UInt32(clamping: line)
    }

    var file: String {
        String(decoding: UnsafeRawBufferPointer(start: fileStart, count: Int(fileLength)), as: UTF8.self)
    }

    var line: Int { Int(lineNumber) }
}

/// ``ParserError``'s hot-path storage: pointers to the hint and file literals.
///
/// Field order matters: `hintIsASCII` sits past byte 16, beyond every other ``ParseFailure`` payload,
/// so its spare bits hold the enum tags and `ParseFailure` stays 24 bytes rather than 25.
private struct LiteralHint: @unchecked Sendable {  // @unchecked: points at immutable string literals.
    private var hintStart: UnsafeRawPointer
    let site: ThrowSite
    private var hintIsASCII: Bool
    private var hintLength: UInt16

    /// `nil` if `hint` is not a pointer-backed literal or is longer than `UInt16.max` bytes.
    init?(_ hint: StaticString, site: ThrowSite) {
        guard hint.hasPointerRepresentation, let length = UInt16(exactly: hint.utf8CodeUnitCount) else {
            return nil
        }
        self.hintStart = UnsafeRawPointer(hint.utf8Start)
        self.site = site
        self.hintIsASCII = hint.isASCII
        self.hintLength = length
    }

    var hint: String {
        let bytes = UnsafeRawBufferPointer(start: hintStart, count: Int(hintLength))
        guard hintIsASCII else { return String(decoding: bytes, as: UTF8.self) }
        return String(decoding: bytes, as: Unicode.ASCII.self)
    }
}

/// ``ParserError``'s storage for a digit-count mismatch: the counts, formatted only when read.
///
/// 20 bytes, so like ``LiteralHint`` it leaves byte 21's spare bits for the enum tags. Counts clamp, which
/// no real value reaches: `expected` is a grammar constant (1, 2 or 4) and `got` is a run of digits in
/// one buffer.
private struct DigitCountHint {
    let site: ThrowSite
    private var expected: UInt16
    private var got: UInt32

    init(expected: Int, got: Int, site: ThrowSite) {
        self.site = site
        self.expected = UInt16(clamping: expected)
        self.got = UInt32(clamping: got)
    }

    var hint: String { "Expected \(expected) digits, got \(got)" }
}

/// ``ParserError``'s cold storage: one allocation, 8 bytes inline.
private final class InterpolatedHint: Sendable {
    let hint: String
    let site: ThrowSite

    init(hint: String, site: ThrowSite) {
        self.hint = hint
        self.site = site
    }
}

/// Signals that a protocol message was too complex and required excessive recursive parsing.
///
/// IMAP protocol elements can nest (for example, nested parenthesized lists in BODYSTRUCTURE),
/// and parsing uses recursion to handle this. To prevent stack overflow attacks,
/// the parser enforces a maximum recursion depth. If this limit is exceeded, this error
/// is thrown.
///
/// A safety limit to prevent malicious or extremely unusual protocol messages
/// from causing a stack overflow.
///
/// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3) (protocol syntax)
public struct TooMuchRecursion: Error {
    /// The maximum number of recursive calls when parsing data before throwing an error.
    ///
    /// The parser maintains a recursion depth counter and throws this error when the
    /// depth would exceed this limit. This prevents stack overflow from deeply nested
    /// protocol structures.
    ///
    /// Currently fixed at compile-time and not configurable at runtime.
    public var limit: Int

    init(limit: Int) {
        self.limit = limit
    }
}

/// Signals that parsing stopped consuming input while it would otherwise have kept going.
///
/// Parsing that produces results without consuming bytes would produce them forever. Rather than spin,
/// the parser throws this, and the connection should be closed: no valid input causes it, so it means
/// either a parser bug or input crafted to find one.
///
/// Unlike ``ParserError`` it is never taken to mean "this alternative did not match", so no
/// backtracking point absorbs it.
public struct NoForwardProgress: Error {
    /// Compact, like ``ParserError``'s: no allocation on the throw, and ``ParseFailure`` stays small.
    private var site: ThrowSite

    /// Creates the error, recording where the check that fired is.
    ///
    /// - Parameters:
    ///   - file: The file of the check. Defaults to the caller's.
    ///   - line: The line of the check. Defaults to the caller's.
    public init(file: StaticString = #fileID, line: Int = #line) {
        self.site = ThrowSite(file: file, line: line)
    }
}

extension NoForwardProgress: CustomStringConvertible {
    /// Names the check that fired, which is what a log of this error is for.
    public var description: String { "NoForwardProgress at \(site.file):\(site.line)" }
}

extension NoForwardProgress: CustomReflectable {
    /// `file` and `line`, as before its storage went compact, rather than raw pointers.
    public var customMirror: Mirror {
        Mirror(self, children: ["file": site.file, "line": site.line], displayStyle: .struct)
    }
}
