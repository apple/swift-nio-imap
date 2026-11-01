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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

import Testing

/// Logs print these errors, so their printed form is public behaviour. The expected strings are what
/// the stored `hint` / `file` / `line` properties printed before `ParserError` went compact.
@Suite("Parser error printing")
struct ParserErrorPrintingTests {
    private static let file: StaticString = "NIOIMAPCore/Foo.swift"

    private func dumped(_ value: Any) -> String {
        var output = ""
        dump(value, to: &output)
        return output
    }

    @Test(
        "ParserError prints hint, file and line",
        arguments: [
            ParserError(hint: "Expected digit", file: Self.file, line: 42),
            ParserError(dynamicHint: "Expected digit", file: Self.file, line: 42),
        ]
    )
    func parserError(_ error: ParserError) {
        let fields = #"(hint: "Expected digit", file: "NIOIMAPCore/Foo.swift", line: 42)"#
        #expect(String(describing: error) == "ParserError" + fields)
        #expect("\(error)" == "ParserError" + fields)
        #expect(String(reflecting: error) == "NIOIMAPCore.ParserError" + fields)
        #expect(
            dumped(error) == """
                ▿ NIOIMAPCore.ParserError
                  - hint: "Expected digit"
                  - file: "NIOIMAPCore/Foo.swift"
                  - line: 42

                """
        )
    }

    @Test("ParserError prints a digit-count hint")
    func digitCountHint() {
        let error = ParserError(expectedDigits: 1, got: 2, file: Self.file, line: 7)
        let fields = #"(hint: "Expected 1 digits, got 2", file: "NIOIMAPCore/Foo.swift", line: 7)"#
        #expect(String(describing: error) == "ParserError" + fields)
        #expect(String(reflecting: error) == "NIOIMAPCore.ParserError" + fields)
        #expect(
            dumped(error) == """
                ▿ NIOIMAPCore.ParserError
                  - hint: "Expected 1 digits, got 2"
                  - file: "NIOIMAPCore/Foo.swift"
                  - line: 7

                """
        )
    }

    @Test("ParserError keeps a digit-count hint's site when the hint is assigned")
    func assignedDigitCountHint() {
        var error = ParserError(expectedDigits: 1, got: 2, file: Self.file, line: 7)
        error.hint = "after"
        #expect(String(describing: error) == #"ParserError(hint: "after", file: "NIOIMAPCore/Foo.swift", line: 7)"#)
    }

    @Test("ParserError prints a non-ASCII hint")
    func nonASCIIHint() {
        let error = ParserError(hint: "Ünïcode ✓", file: Self.file, line: 7)
        #expect(String(describing: error) == #"ParserError(hint: "Ünïcode ✓", file: "NIOIMAPCore/Foo.swift", line: 7)"#)
    }

    @Test("ParserError prints an assigned hint")
    func assignedHint() {
        var error = ParserError(hint: "before", file: Self.file, line: 7)
        error.hint = "after"
        #expect(String(describing: error) == #"ParserError(hint: "after", file: "NIOIMAPCore/Foo.swift", line: 7)"#)
    }

    @Test("BadCommand prints its ParserError's fields")
    func badCommand() {
        let error = BadCommand(
            commandTag: "A1",
            parserError: ParserError(hint: "Expected digit", file: Self.file, line: 42)
        )
        let parserError = #"NIOIMAPCore.ParserError(hint: "Expected digit", file: "NIOIMAPCore/Foo.swift", line: 42)"#
        #expect(String(describing: error) == #"BadCommand(commandTag: A1, parserError: "# + parserError + ")")
        #expect(
            String(reflecting: error) == #"NIOIMAPCore.BadCommand(commandTag: A1, parserError: "# + parserError + ")"
        )
        #expect(
            dumped(error) == """
                ▿ NIOIMAPCore.BadCommand
                  ▿ commandTag: A1
                    - stringValue: "A1"
                  ▿ parserError: NIOIMAPCore.ParserError
                    - hint: "Expected digit"
                    - file: "NIOIMAPCore/Foo.swift"
                    - line: 42

                """
        )
    }

    @Test("NoForwardProgress prints file and line")
    func noForwardProgress() {
        let error = NoForwardProgress(file: Self.file, line: 3)
        #expect(String(describing: error) == "NoForwardProgress at NIOIMAPCore/Foo.swift:3")
        #expect(String(reflecting: error) == "NoForwardProgress at NIOIMAPCore/Foo.swift:3")
        #expect(
            dumped(error) == """
                ▿ NoForwardProgress at NIOIMAPCore/Foo.swift:3
                  - file: "NIOIMAPCore/Foo.swift"
                  - line: 3

                """
        )
    }
}
