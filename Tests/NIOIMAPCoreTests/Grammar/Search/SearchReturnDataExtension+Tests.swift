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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("SearchReturnDataExtension")
struct SearchReturnDataExtensionTests {
    @Test(arguments: [
        EncodeFixture.searchReturnDataExtension(.init(key: "modifier", value: .sequence(.set([123]))), "modifier 123")
    ])
    func encode(_ fixture: EncodeFixture<KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchReturnDataExtension(
            "modifier 64",
            expected: .success(.init(key: "modifier", value: .sequence(.set([64]))))
        )
    ])
    func parse(_ fixture: ParseFixture<KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>> {
    fileprivate static func searchReturnDataExtension(
        _ input: KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchReturnDataExtension($1) }
        )
    }
}

extension ParseFixture<KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>> {
    fileprivate static func searchReturnDataExtension(
        _ input: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: "\r",
            expected: expected,
            parser: GrammarParser().parseSearchReturnDataExtension
        )
    }
}
