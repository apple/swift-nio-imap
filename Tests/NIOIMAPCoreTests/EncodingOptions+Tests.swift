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

@Suite("EncodingOptions")
private struct EncodingOptionsTests {
    @Test(
        arguments: [
            OptionsFixture(capabilities: [], expected: CommandEncodingOptions()),
            OptionsFixture(
                capabilities: [.literalPlus],
                expected: CommandEncodingOptions(useNonSynchronizingLiteralPlus: true)
            ),
            OptionsFixture(
                capabilities: [.literalMinus],
                expected: CommandEncodingOptions(useNonSynchronizingLiteralMinus: true)
            ),
            OptionsFixture(capabilities: [.binary], expected: CommandEncodingOptions(useBinaryLiteral: true)),
        ] as [OptionsFixture<CommandEncodingOptions>]
    )
    func commandOptionsFromCapabilities(_ fixture: OptionsFixture<CommandEncodingOptions>) {
        #expect(CommandEncodingOptions(capabilities: fixture.capabilities) == fixture.expected)
    }

    @Test(
        "response options from capabilities",
        arguments: [
            OptionsFixture(capabilities: [.imap4rev1], expected: ResponseEncodingOptions())
        ] as [OptionsFixture<ResponseEncodingOptions>]
    )
    func responseOptionsFromCapabilities(_ fixture: OptionsFixture<ResponseEncodingOptions>) {
        #expect(ResponseEncodingOptions(capabilities: fixture.capabilities) == fixture.expected)
    }

    @Test("updateEnabledOptions removes useSearchCharset")
    func updateEnabledOptionsRemovesSearchCharset() {
        var options = CommandEncodingOptions()
        #expect(options.useSearchCharset == true)
        options.updateEnabledOptions(capabilities: [.utf8(.accept)])
        #expect(options.useSearchCharset == false)
    }
}

// MARK: -

private struct OptionsFixture<O: Equatable & Sendable>: CustomTestStringConvertible, Sendable {
    var capabilities: [Capability]
    var expected: O

    var testDescription: String { capabilities.map { String(reflecting: $0) }.joined(separator: " ") }
}
