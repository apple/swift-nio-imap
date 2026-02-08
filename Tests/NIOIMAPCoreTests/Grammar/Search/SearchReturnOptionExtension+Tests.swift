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

@Suite("SearchReturnOptionExtension")
struct SearchReturnOptionExtensionTests {
    @Test(arguments: [
        EncodeFixture.searchReturnOptionExtension(
            .init(key: "modifier", value: nil),
            "modifier"
        ),
        EncodeFixture.searchReturnOptionExtension(
            .init(key: "modifier", value: .sequence(.set([4]))),
            "modifier 4"
        ),
    ])
    func encode(_ fixture: EncodeFixture<KeyValue<String, ParameterValue?>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchReturnOptionExtension("modifier", "\r", expected: .success(.init(key: "modifier", value: nil))),
        ParseFixture.searchReturnOptionExtension("modifier 4", "\r", expected: .success(.init(key: "modifier", value: .sequence(.set([4]))))),
        ParseFixture.searchReturnOptionExtension("modifier ", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<KeyValue<String, ParameterValue?>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<String, ParameterValue?>> {
    fileprivate static func searchReturnOptionExtension(
        _ input: KeyValue<String, ParameterValue?>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchReturnOptionExtension($1) }
        )
    }
}

extension ParseFixture<KeyValue<String, ParameterValue?>> {
    fileprivate static func searchReturnOptionExtension(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchReturnOptionExtension
        )
    }
}
