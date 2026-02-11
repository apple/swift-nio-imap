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

import NIO
@testable import NIOIMAPCore
import NIOTestUtils
import XCTest

extension StackTracker {
    static var testTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 30)
    }
}

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

protocol _ParserTestHelpers {}

final class ParserUnitTests: XCTestCase, _ParserTestHelpers {}

extension _ParserTestHelpers {
    private func iterateTestInputs_generic<T: Equatable>(
        _ inputs: [(String, String, T, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> T
    ) {
        for (input, terminator, expected, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: false,
                file: file,
                line: line
            ) { (buffer) in
                let testValue = try testFunction(&buffer, .testTracker)
                XCTAssertEqual(testValue, expected, file: file, line: line)
            }
        }
    }

    private func iterateInvalidTestInputs_ParserError_generic<T: Equatable>(
        _ inputs: [(String, String, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> T
    ) {
        for (input, terminator, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                file: file,
                line: line
            ) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), file: file, line: line) { e in
                    XCTAssertTrue(e is ParserError, "Expected ParserError, got \(e)", file: file, line: line)
                }
            }
        }
    }

    private func iterateInvalidTestInputs_IncompleteMessage_generic<T: Equatable>(
        _ inputs: [(String, String, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> T
    ) {
        for (input, terminator, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                file: file,
                line: line
            ) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), file: file, line: line) { e in
                    XCTAssertTrue(
                        e is IncompleteMessage,
                        "Expected IncompleteMessage, got \(e)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    private func iterateTestInputs(
        _ inputs: [(String, String, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> Void
    ) {
        for (input, terminator, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: false,
                file: file,
                line: line
            ) { (buffer) in
                try testFunction(&buffer, .testTracker)
            }
        }
    }

    private func iterateInvalidTestInputs_ParserError(
        _ inputs: [(String, String, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> Void
    ) {
        for (input, terminator, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                file: file,
                line: line
            ) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), file: file, line: line) { e in
                    XCTAssertTrue(e is ParserError, "Expected ParserError, got \(e)", file: file, line: line)
                }
            }
        }
    }

    private func iterateInvalidTestInputs_IncompleteMessage(
        _ inputs: [(String, String, UInt)],
        file: StaticString = #filePath,
        testFunction: (inout ParseBuffer, StackTracker) throws -> Void
    ) {
        for (input, terminator, line) in inputs {
            TestUtilities.withParseBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                file: file,
                line: line
            ) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), file: file, line: line) { e in
                    XCTAssertTrue(
                        e is IncompleteMessage,
                        "Expected IncompleteMessage, got \(e)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    /// Convenience function to run a variety of happy and non-happy tests.
    /// - parameter testFunction: The function to be tested, inputs will be provided to this function.
    /// - parameter validInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should succeed.
    /// - parameter parserErrorInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing a `ParserError`.
    /// - parameter incompleteMessageInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing an `_IncompleteMessage`.
    func iterateTests<T: Equatable>(
        testFunction: (inout ParseBuffer, StackTracker) throws -> T,
        validInputs: [(String, String, T, UInt)],
        parserErrorInputs: [(String, String, UInt)],
        incompleteMessageInputs: [(String, String, UInt)],
        file: StaticString = #filePath
    ) {
        self.iterateTestInputs_generic(validInputs, file: file, testFunction: testFunction)
        self.iterateInvalidTestInputs_ParserError_generic(parserErrorInputs, file: file, testFunction: testFunction)
        self.iterateInvalidTestInputs_IncompleteMessage_generic(
            incompleteMessageInputs,
            file: file,
            testFunction: testFunction
        )
    }

    /// Convenience function to run a variety of happy and non-happy tests.
    /// - parameter testFunction: The function to be tested, inputs will be provided to this function.
    /// - parameter validInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should succeed.
    /// - parameter parserErrorInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing a `ParserError`.
    /// - parameter incompleteMessageInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing an `_IncompleteMessage`.
    func iterateTests(
        testFunction: (inout ParseBuffer, StackTracker) throws -> Void,
        validInputs: [(String, String, UInt)],
        parserErrorInputs: [(String, String, UInt)],
        incompleteMessageInputs: [(String, String, UInt)],
        file: StaticString = #filePath
    ) {
        self.iterateTestInputs(validInputs, file: file, testFunction: testFunction)
        self.iterateInvalidTestInputs_ParserError(parserErrorInputs, file: file, testFunction: testFunction)
        self.iterateInvalidTestInputs_IncompleteMessage(incompleteMessageInputs, file: file, testFunction: testFunction)
    }
}
