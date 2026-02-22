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

@Suite("URLFetchData")
struct URLFetchDataTests {
    @Test(arguments: [
        EncodeFixture.urlFetchData(
            .init(url: "url", data: nil),
            "\"url\" NIL"
        ),
        EncodeFixture.urlFetchData(
            .init(url: "url", data: "data"),
            "\"url\" \"data\""
        ),
    ])
    func encode(_ fixture: EncodeFixture<URLFetchData>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.urlFetchData(
            "url NIL",
            " ",
            expected: .success(.init(url: "url", data: nil))
        ),
        ParseFixture.urlFetchData(
            "url \"data\"",
            " ",
            expected: .success(.init(url: "url", data: "data"))
        ),
    ])
    func parse(_ fixture: ParseFixture<URLFetchData>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<URLFetchData> {
    fileprivate static func urlFetchData(
        _ input: URLFetchData,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLFetchData($1) }
        )
    }
}

extension ParseFixture<URLFetchData> {
    fileprivate static func urlFetchData(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseURLFetchData
        )
    }
}
