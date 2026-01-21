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

@Suite("NamespaceDescription")
struct NamespaceDescriptionTests {
    @Test(arguments: [
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: nil, responseExtensions: [:]),
            "(\"string\" NIL)"
        ),
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: "a", responseExtensions: [:]),
            "(\"string\" \"a\")"
        ),
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: nil, responseExtensions: ["str2": ["str3"]]),
            "(\"string\" NIL \"str2\" (\"str3\"))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NamespaceDescription>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<NamespaceDescription> {
    fileprivate static func namespaceDescription(
        _ input: NamespaceDescription,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNamespaceDescription($1) }
        )
    }
}
