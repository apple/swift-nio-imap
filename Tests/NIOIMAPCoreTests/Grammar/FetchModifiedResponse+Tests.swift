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

@Suite("FetchModificationResponse")
struct FetchModificationResponseTests {
    @Test(arguments: [
        EncodeFixture.fetchModificationResponse(
            .init(modifierSequenceValue: 3),
            "MODSEQ (3)"
        ),
        EncodeFixture.fetchModificationResponse(
            .init(modifierSequenceValue: 12345),
            "MODSEQ (12345)"
        )
    ])
    func encode(_ fixture: EncodeFixture<FetchModificationResponse>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture<FetchModificationResponse> {
    fileprivate static func fetchModificationResponse(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeFetchModificationResponse($1) }
        )
    }
}
