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
struct NamespaceTests {
    @Test(arguments: [
        EncodeFixture.namespace([], "NIL"),
        EncodeFixture.namespace(
            [.init(string: "str1", char: nil, responseExtensions: [:])],
            "((\"str1\" NIL))"
        ),
        EncodeFixture.namespace(
            [
                .init(string: "str1", char: nil, responseExtensions: [:]),
                .init(string: "str2", char: nil, responseExtensions: [:])
            ],
            "((\"str1\" NIL)(\"str2\" NIL))"
        )
    ])
    func encode(_ fixture: EncodeFixture<[NamespaceDescription]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<[NamespaceDescription]> {
    fileprivate static func namespace(
        _ input: [NamespaceDescription],
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNamespace($1) }
        )
    }
}
