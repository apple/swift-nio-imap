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

@Suite("ListSelectBaseOption")
struct ListSelectBaseOptionTests {
    @Test(arguments: [
        EncodeFixture.listSelectBaseOption(.subscribed, "SUBSCRIBED"),
        EncodeFixture.listSelectBaseOption(.option(.init(key: .standard("test"), value: nil)), "test"),
    ])
    func encode(_ fixture: EncodeFixture<ListSelectBaseOption>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode quoted",
        arguments: [
            EncodeFixture.listSelectBaseOptionQuoted(.subscribed, #""SUBSCRIBED""#)
        ]
    )
    func encodeQuoted(_ fixture: EncodeFixture<ListSelectBaseOption>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ListSelectBaseOption> {
    fileprivate static func listSelectBaseOption(
        _ input: ListSelectBaseOption,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectBaseOption($1) }
        )
    }

    fileprivate static func listSelectBaseOptionQuoted(
        _ input: ListSelectBaseOption,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectBaseOptionQuoted($1) }
        )
    }
}
