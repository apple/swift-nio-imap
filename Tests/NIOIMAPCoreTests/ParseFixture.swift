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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

/// A fixture for testing IMAP parsing.
/// Captures the input value, encoding options, expected output, and encoder function.
struct ParseFixture<T>: Sendable where T: Sendable {
    /// The input to be parsed.
    var input: String
    /// A terminator string to be appended after the input.
    ///
    /// The expectation is that (successful) parsing would stop at this terminator.
    var terminator: String
    /// Should parsing succeed, fail, etc.?
    var expected: Expected
    /// The parser being tested.
    var parser: @Sendable (inout ParseInput, StackTracker) throws -> T

    enum Expected: Sendable {
        /// The input is valid.
        case success(T)
        /// The input is valid, but only a partial message. Waiting for more input.
        case incompleteMessage
        /// The input is valid, but only a partial message. Waiting for more input.
        /// We don’t expect the buffer to remain unchanged.
        /// This is for parsers that don't save+restore on failure because they’re expected
        /// to only be used from within another parser that does so.
        case incompleteMessageIgnoringBufferModifications
        /// The input is invalid. Should throw ``ParserError``.
        case failure
        /// The input is invalid. Should throw an error of the given type.
        case failureThrowing(any Error.Type)
        /// The input is invalid. Should throw ``ParserError``.
        /// We don’t expect the buffer to remain unchanged.
        /// This is for parsers that don't save+restore on failure because they’re expected
        /// to only be used from within another parser that does so.
        case failureIgnoringBufferModifications
        /// The input is invalid. Should throw an error of the given type.
        /// We don’t expect the buffer to remain unchanged.
        case failureIgnoringBufferModificationsThrowing(any Error.Type)
    }
}

// MARK: -

extension ParseFixture: CustomTestArgumentEncodable {
    func encodeTestArgument(to encoder: some Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(input)
        try c.encode(terminator)
    }
}

extension ParseFixture: CustomTestStringConvertible {
    var testDescription: String {
        (input + terminator).mappingControlPictures()
    }
}

extension ParseFixture {
    func checkParsing(
        sourceLocation: SourceLocation = #_sourceLocation
    ) where T: Equatable {
        switch expected {
        case .success(let expectedValue):
            ParseInputFixture.withInput(
                input,
                terminator: terminator,
                finalBufferExpectation: .terminatorOnly,
                sourceLocation: sourceLocation
            ) { buffer in
                do {
                    let parsed = try parser(&buffer, .testTracker)
                    #expect(parsed == expectedValue, sourceLocation: sourceLocation)
                } catch {
                    Issue.record(error, "Parsing should succeed", sourceLocation: sourceLocation)
                }
            }
        case .incompleteMessage:
            expectFailure(
                .initialCondition,
                IncompleteMessage.self,
                "The input buffer is incomplete. Should throw IncompleteMessage.",
                sourceLocation: sourceLocation
            )
        case .incompleteMessageIgnoringBufferModifications:
            expectFailure(
                .ignore,
                IncompleteMessage.self,
                "The input buffer is incomplete. Should throw IncompleteMessage.",
                sourceLocation: sourceLocation
            )
        case .failure:
            expectFailure(
                .initialCondition,
                ParserError.self,
                "Should throw ParserError.",
                sourceLocation: sourceLocation
            )
        case .failureThrowing(let errorType):
            expectFailure(.initialCondition, errorType, "Should throw \(errorType).", sourceLocation: sourceLocation)
        case .failureIgnoringBufferModifications:
            expectFailure(.ignore, ParserError.self, "Should throw ParserError.", sourceLocation: sourceLocation)
        case .failureIgnoringBufferModificationsThrowing(let errorType):
            expectFailure(.ignore, errorType, "Should throw \(errorType).", sourceLocation: sourceLocation)
        }
    }

    /// Runs the parser and requires it to throw an error of type `expectedError`.
    ///
    /// `#expect(throws:)` cannot wrap a parse: its closure would have to capture an `inout` value of a
    /// non-escapable type, which is exactly what a cursor is.
    private func expectFailure(
        _ finalBufferExpectation: ParseInputFixture.FinalBufferExpectation,
        _ expectedError: any Error.Type,
        _ comment: Comment,
        sourceLocation: SourceLocation
    ) {
        ParseInputFixture.withInput(
            input,
            terminator: terminator,
            finalBufferExpectation: finalBufferExpectation,
            sourceLocation: sourceLocation
        ) { buffer in
            guard let error = errorThrown(by: { try parser(&buffer, .testTracker) }) else {
                Issue.record(comment, sourceLocation: sourceLocation)
                return
            }
            #expect(
                type(of: error) == expectedError,
                "\(comment) Got \(type(of: error)).",
                sourceLocation: sourceLocation
            )
        }
    }
}

/// Drives a ``ParseInput`` over a fixture's input, and checks what the parser left behind.
enum ParseInputFixture {
    /// What the input should look like once the parser has run.
    enum FinalBufferExpectation: Hashable, Sendable {
        /// Only the terminator (and anything trailing it) should be left.
        case terminatorOnly
        /// Nothing should have been consumed.
        case initialCondition
        /// Don't check.
        case ignore
    }

    /// Runs `body` with a cursor over `string + terminator`, then checks what it left unconsumed.
    ///
    /// The input is padded on both sides — bytes before the first visible byte and after the last —
    /// so that a parser which reads outside the region it was given is caught rather than silently
    /// right. An `ArraySlice` is how that padding is expressed: the bytes are there, in the same
    /// allocation, and the region the parser sees is a slice that excludes them.
    static func withInput(
        _ string: String,
        terminator: String,
        finalBufferExpectation: FinalBufferExpectation,
        sourceLocation: SourceLocation,
        _ body: (inout ParseInput) -> Void
    ) {
        let padded = Array("hello\(string)\(terminator)hallo".utf8)
        let inputBuffer = padded[5..<(padded.count - 5)]

        inputBuffer.withParseInput { input in
            body(&input)
            guard finalBufferExpectation != .ignore else { return }
            let remaining = (try? input.extractBytes(length: input.remaining)) ?? []
            let expected = finalBufferExpectation == .terminatorOnly ? terminator : string + terminator
            #expect(
                String(decoding: remaining, as: UTF8.self) == expected,
                finalBufferExpectation == .terminatorOnly
                    ? "Terminator (and trailing) should remain in the input, nothing else."
                    : "The input should remain unchanged.",
                sourceLocation: sourceLocation
            )
        }
    }
}
