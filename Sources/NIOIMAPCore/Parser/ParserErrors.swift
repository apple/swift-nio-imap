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
/// - Throws: ``ParserError`` when `bytes` are not valid UTF-8.
func decodeUTF8(
    _ bytes: some Collection<UInt8>,
    file: StaticString = (#fileID),
    line: Int = #line
) throws -> String {
    guard let string = String(validatingUTF8Bytes: bytes) else {
        throw ParserError.invalidUTF8(file: file, line: line)
    }
    return string
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
    static func invalidUTF8(file: StaticString = (#fileID), line: Int = #line) -> Self {
        ParserError(hint: "Invalid UTF8", file: file, line: line)
    }

    /// If possible, a description of the error and why it occurred.
    ///
    /// Describes the parsing failure in human-readable terms, such as
    /// "Invalid UTF8", "Missing CRLF", "Unexpected character", etc. It's intended
    /// for logging and debugging purposes.
    public var hint: String
    /// `StaticString` rather than `String`: `#fileID` is longer than the 15-byte small-string limit,
    /// so a `String` here would heap-allocate and retain on *every* throw, hint or no hint.
    var file: StaticString
    var line: Int

    init(hint: String = "Unknown", file: StaticString = (#fileID), line: Int = #line) {
        self.hint = hint
        self.file = file
        self.line = line
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
