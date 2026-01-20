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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("EncodedSearch")
struct EncodedSearchTests {
    @Test(arguments: [
        EncodeFixture.encodedSearch(.init(query: "hello"), "hello"),
    ])
    func encode(_ fixture: EncodeFixture<EncodedSearch>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<EncodedSearch> {
    fileprivate static func encodedSearch(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedSearch($1) }
        )
    }
}
