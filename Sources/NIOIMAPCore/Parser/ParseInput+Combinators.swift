//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct OrderedCollections.OrderedDictionary

/// One step of the grammar: reads from the cursor, and either produces a value or throws.
///
/// Pass an annotated closure, `{ b, t throws(ParseFailure) in try parseX(buffer: &b, tracker: t) }`, or a
/// method reference, `self.parseX`:
/// - Closure literals don't infer typed throws from context, so the `throws(ParseFailure)` is required.
///   `$0`/`$1` can't be combined with the annotation; name the parameters.
/// - A bare local function `parseX` doesn't work: a local `func` taking `inout ParseInput` carries an
///   inferred lifetime dependency that function types cannot express before Swift 6.4
///   (swiftlang/swift#86842), so 6.2 and 6.3 reject the reference. Revisit once 6.4 is the minimum:
///   https://github.com/apple/swift-nio-imap/issues/875
/// - For the array form of `parseOneOf`, wrap each alternative in a ``ParseAlternative``.
typealias SubParser<T> = (inout ParseInput, StackTracker) throws(ParseFailure) -> T

/// One alternative for the array form of `parseOneOf`.
///
/// An array stores a bare ``SubParser`` in the most general convention (indirect result and error), so a
/// typed-throws closure needs a reabstraction thunk to go in, with a heap context per capturing closure.
/// A closure literal passed to this init is emitted directly in the field's convention (concrete error):
/// no thunk. A `SubParser` value or a method reference still needs one, so pass the literal. One `let`
/// per alternative: a typed-throws closure literal as an array element crashes SILGen (6.3, 6.4).
/// ```
/// let a = ParseAlternative<X> { b, t throws(ParseFailure) in try parseA(buffer: &b, tracker: t) }
/// let b = ParseAlternative<X> { b, t throws(ParseFailure) in try self.parseB(buffer: &b, tracker: t) }
/// return try buffer.parseOneOf([a, b], tracker: tracker)
/// ```
struct ParseAlternative<T> {
    let parse: SubParser<T>

    init(_ parse: @escaping SubParser<T>) {
        self.parse = parse
    }
}

// MARK: - Character classes

extension ParseInput {
    /// Consumes and returns the leading bytes that satisfy `predicate`, of which there may be none.
    ///
    /// - Throws: ``ParseFailure/incomplete`` when every visible byte satisfies `predicate`, since the run
    ///   may continue into bytes that have not arrived yet.
    @_lifetime(self: copy self)
    mutating func parseZeroOrMoreCharacters(where predicate: (UInt8) -> Bool) throws(ParseFailure) -> [UInt8] {
        guard let count = scanWhile(predicate) else { throw .incomplete }
        return try extractBytes(length: count)
    }

    /// Consumes and returns the leading bytes that satisfy `predicate`, of which there must be at least
    /// one.
    ///
    /// - Throws: ``ParseFailure/incomplete`` when every visible byte satisfies `predicate`;
    ///   ``ParseFailure/mismatch(_:)`` when the very first byte does not.
    @_lifetime(self: copy self)
    mutating func parseOneOrMoreCharacters(where predicate: (UInt8) -> Bool) throws(ParseFailure) -> [UInt8] {
        guard let count = scanWhile(predicate) else { throw .incomplete }
        guard count > 0 else { throw .mismatch("Unexpected byte") }
        return try extractBytes(length: count)
    }

    /// Consumes one or more spaces.
    ///
    /// Consumes nothing unless it succeeds, so a caller does not need to wrap this in
    /// ``composite(tracker:_:)`` to keep its position on a failure.
    ///
    /// - Throws: ``ParseFailure/incomplete`` when the input is empty; ``ParseFailure/mismatch(_:)`` when
    ///   the first byte is not a space.
    mutating func parseSpaces() throws(ParseFailure) {
        // Not `scanWhile == nil`-as-incomplete: a run of spaces reaching the end of the input *is* a
        // complete run of spaces as far as this cursor can tell, and the old implementation consumed it.
        guard let first = peek(at: 0) else { throw .incomplete }
        guard first == UInt8(ascii: " ") else { throw .mismatch("Expected space") }
        guard let count = scanWhile({ $0 == UInt8(ascii: " ") }) else {
            advance(by: remaining)
            return
        }
        advance(by: count)
    }
}

// MARK: - Matching

extension ParseInput {
    /// Whether ``matchFixed(_:caseSensitivity:leadingSpaces:)`` skips spaces before the needle.
    enum LeadingSpaces {
        /// `")"` also matches `"  )"`.
        case allowed
        /// `")"` matches only `")"`.
        case rejected
    }

    /// Consumes `needle`, optionally allowing spaces in front of it, and consumes nothing otherwise.
    ///
    /// The leading-space form saves and restores the cursor itself rather than taking a
    /// ``StackTracker``: skipping spaces cannot recurse, so it needs no stack frame.
    @_lifetime(self: copy self)
    mutating func matchFixed(
        _ needle: String,
        caseSensitivity: CaseSensitivity = .caseInsensitive,
        leadingSpaces: LeadingSpaces
    ) throws(ParseFailure) {
        guard leadingSpaces == .allowed else {
            return try matchFixed(needle, caseSensitivity: caseSensitivity)
        }
        let save = copy self
        do {
            // Spaces are optional; incomplete still propagates.
            do { try parseSpaces() } catch .mismatch {}
            try matchFixed(needle, caseSensitivity: caseSensitivity)
        } catch {
            self = save
            throw error
        }
    }

    /// Consumes one byte and requires it to be `needle`. Consumes nothing otherwise.
    @_lifetime(self: copy self)
    mutating func matchByte(_ needle: Character) throws(ParseFailure) {
        assert(needle.isASCII)
        guard let byte = peek(at: 0) else { throw .incomplete }
        guard byte == needle.asciiValue! else { throw .mismatch("Unexpected byte") }
        advance(by: 1)
    }
}

// MARK: - Numbers

extension ParseInput {
    /// Whether ``parseUnsignedInt64(tracker:leadingZeros:)`` accepts a number that starts with `0`.
    enum LeadingZeros {
        /// `007` parses as 7.
        case allowed
        /// A leading `0` is a mismatch, even `0` itself.
        case rejected
    }

    /// Consumes a run of ASCII digits and returns its value along with how many digits it took.
    @_lifetime(self: copy self)
    mutating func parseUnsignedInteger(
        tracker: StackTracker,
        leadingZeros: LeadingZeros = .rejected
    ) throws(ParseFailure) -> (number: Int, bytesConsumed: Int) {
        let largeInt = try parseUnsignedInt64(tracker: tracker, leadingZeros: leadingZeros)
        guard let int = Int(exactly: largeInt.number) else {
            throw .mismatch("integer too large")
        }
        return (number: int, bytesConsumed: largeInt.bytesConsumed)
    }

    /// Consumes a run of ASCII digits and returns its value along with how many digits it took.
    @_lifetime(self: copy self)
    mutating func parseUnsignedInt64(
        tracker: StackTracker,
        leadingZeros: LeadingZeros = .rejected
    ) throws(ParseFailure) -> (number: UInt64, bytesConsumed: Int) {
        try composite(tracker: tracker) { input, _ throws(ParseFailure) in
            let digits = try input.parseOneOrMoreCharacters { char in
                char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")
            }
            if leadingZeros == .rejected, digits.first == UInt8(ascii: "0") {
                throw .mismatch("starts with 0")
            }
            // Accumulating rather than going through `UInt64(String)` keeps a per-integer allocation off
            // a path taken for every UID, size and sequence number.
            var value: UInt64 = 0
            for digit in digits {
                let (multiplied, overflowedMultiply) = value.multipliedReportingOverflow(by: 10)
                guard !overflowedMultiply else { throw .mismatch("number is too large") }
                let (added, overflowedAdd) = multiplied.addingReportingOverflow(
                    UInt64(digit - UInt8(ascii: "0"))
                )
                guard !overflowedAdd else { throw .mismatch("number is too large") }
                value = added
            }
            return (value, digits.count)
        }
    }
}

// MARK: - Combinators

extension ParseInput {
    /// Runs `parser`, and returns `nil` — having consumed nothing — if it fails to match.
    ///
    /// Only ``ParseFailure/mismatch(_:)`` means "did not match": ``ParseFailure/incomplete`` propagates,
    /// because more bytes could still make this parser succeed and the caller must be able to wait for
    /// them. So does every other failure, ``ParseFailure/badCommand(_:)`` included.
    @_lifetime(self: copy self)
    mutating func parseOptional<T>(tracker: StackTracker, parser: SubParser<T>) throws(ParseFailure) -> T? {
        do {
            return try composite(tracker: tracker, parser)
        } catch .mismatch {
            return nil
        }
    }

    /// Runs `parser` until it stops matching, handing each result to `body`.
    ///
    /// A match that consumes nothing would match again at the same position forever, so it throws
    /// ``NoForwardProgress`` instead. No production used with the repetition combinators matches empty
    /// today; this keeps a future one from becoming a hang on peer input.
    @_lifetime(self: copy self)
    mutating func forEachRepetition<T>(
        tracker: StackTracker,
        parser: SubParser<T>,
        _ body: (T) -> Void
    ) throws(ParseFailure) {
        while true {
            let mark = consumed
            guard let next = try parseOptional(tracker: tracker, parser: parser) else { return }
            try requireProgress(since: mark)
            body(next)
        }
    }

    /// Runs each of `subParsers` in turn and returns the first result, consuming nothing for the
    /// alternatives that fail.
    ///
    /// Moves on after ``ParseFailure/mismatch(_:)`` or ``ParseFailure/badCommand(_:)``; anything else
    /// propagates.
    @_lifetime(self: copy self)
    mutating func parseOneOf<T>(
        _ subParsers: [ParseAlternative<T>],
        tracker: StackTracker,
        file: StaticString = #fileID,
        line: Int = #line
    ) throws(ParseFailure) -> T {
        for parser in subParsers {
            do {
                return try composite(tracker: tracker, parser.parse)
            } catch .mismatch, .badCommand {
                continue
            }
        }
        throw .mismatch("none of the options match", file: file, line: line)
    }

    /// Two-alternative form. Spelled out rather than built on the array form so that the common case
    /// does not allocate an array of closures per call.
    @_lifetime(self: copy self)
    mutating func parseOneOf<T>(
        _ parser1: SubParser<T>,
        _ parser2: SubParser<T>,
        tracker: StackTracker,
        file: StaticString = #fileID,
        line: Int = #line
    ) throws(ParseFailure) -> T {
        do {
            return try composite(tracker: tracker, parser1)
        } catch .mismatch, .badCommand {
            // Try the next alternative.
        }

        return try composite(tracker: tracker, parser2)
    }

    /// Three-alternative form.
    @_lifetime(self: copy self)
    mutating func parseOneOf<T>(
        _ parser1: SubParser<T>,
        _ parser2: SubParser<T>,
        _ parser3: SubParser<T>,
        tracker: StackTracker,
        file: StaticString = #fileID,
        line: Int = #line
    ) throws(ParseFailure) -> T {
        do {
            return try composite(tracker: tracker, parser1)
        } catch .mismatch, .badCommand {
            // Try the next alternative.
        }

        do {
            return try composite(tracker: tracker, parser2)
        } catch .mismatch, .badCommand {
            // Try the next alternative.
        }

        return try composite(tracker: tracker, parser3)
    }

    /// Runs `parser` until it stops matching, requiring at least one match.
    @_lifetime(self: copy self)
    mutating func parseOneOrMore<T>(tracker: StackTracker, parser: SubParser<T>) throws(ParseFailure) -> [T] {
        var parsed: [T] = []
        try parseOneOrMore(into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    /// Runs `parser` until it stops matching, requiring at least one match, appending as it goes.
    @_lifetime(self: copy self)
    mutating func parseOneOrMore<T>(
        into parsed: inout [T],
        tracker: StackTracker,
        parser: SubParser<T>
    ) throws(ParseFailure) {
        try composite(tracker: tracker) { input, tracker throws(ParseFailure) in
            parsed.append(try parser(&input, tracker))
            try input.forEachRepetition(tracker: tracker, parser: parser) { parsed.append($0) }
        }
    }

    /// Runs `parser` until it stops matching, which may be immediately.
    @_lifetime(self: copy self)
    mutating func parseZeroOrMore<T>(tracker: StackTracker, parser: SubParser<T>) throws(ParseFailure) -> [T] {
        var parsed: [T] = []
        try parseZeroOrMore(into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    /// Runs `parser` until it stops matching, which may be immediately, appending as it goes.
    @_lifetime(self: copy self)
    mutating func parseZeroOrMore<T>(
        into parsed: inout [T],
        tracker: StackTracker,
        parser: SubParser<T>
    ) throws(ParseFailure) {
        try composite(tracker: tracker) { input, tracker throws(ParseFailure) in
            try input.forEachRepetition(tracker: tracker, parser: parser) { parsed.append($0) }
        }
    }

    /// Runs `parser` until it stops matching, collecting key/value pairs.
    @_lifetime(self: copy self)
    mutating func parseZeroOrMore<K, V>(
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: SubParser<(K, V)>
    ) throws(ParseFailure) {
        try composite(tracker: tracker) { input, tracker throws(ParseFailure) in
            try input.forEachRepetition(tracker: tracker, parser: parser) { orderedDictionary[$0.0] = $0.1 }
        }
    }

    /// Runs `parser` until it stops matching, collecting ``KeyValue`` pairs.
    @_lifetime(self: copy self)
    mutating func parseZeroOrMore<K, V>(
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: SubParser<KeyValue<K, V>>
    ) throws(ParseFailure) {
        try composite(tracker: tracker) { input, tracker throws(ParseFailure) in
            try input.forEachRepetition(tracker: tracker, parser: parser) { orderedDictionary[$0.key] = $0.value }
        }
    }
}
