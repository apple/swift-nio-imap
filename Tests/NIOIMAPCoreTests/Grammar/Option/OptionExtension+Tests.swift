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

@Suite("OptionExtension KeyValue")
struct OptionExtensionTests {
    @Test(arguments: [
        EncodeFixture.optionExtension(
            .init(key: .standard("test"), value: .string("string")),
            "test (\"string\")"
        ),
        EncodeFixture.optionExtension(
            .init(key: .vendor(.init(key: "token", value: "atom")), value: nil),
            "token-atom"
        ),
        EncodeFixture.optionExtension(
            .init(key: .vendor(.init(key: "token", value: "atom")), value: .string("value")),
            "token-atom (\"value\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<KeyValue<OptionExtensionKind, OptionValueComp?>>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<OptionExtensionKind, OptionValueComp?>> {
    fileprivate static func optionExtension(
        _ input: KeyValue<OptionExtensionKind, OptionValueComp?>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionExtension($1) }
        )
    }
}
