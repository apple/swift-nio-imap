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

@Suite("NamespaceResponse")
struct NamespaceResponseTests {
    @Test(arguments: [
        EncodeFixture.namespaceResponse(
            .init(userNamespace: [], otherUserNamespace: [], sharedNamespace: []),
            "NAMESPACE NIL NIL NIL"
        ),
        EncodeFixture.namespaceResponse(
            .init(
                userNamespace: [NamespaceDescription(string: "", responseExtensions: [:])],
                otherUserNamespace: [NamespaceDescription(string: "#shared/", char: "/", responseExtensions: [:])],
                sharedNamespace: [NamespaceDescription(string: "Public Folders/", responseExtensions: [:])],
            ),
            "NAMESPACE ((\"\" NIL)) ((\"#shared/\" \"/\")) ((\"Public Folders/\" NIL))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NamespaceResponse>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<NamespaceResponse> {
    fileprivate static func namespaceResponse(
        _ input: NamespaceResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNamespaceResponse($1) }
        )
    }
}
