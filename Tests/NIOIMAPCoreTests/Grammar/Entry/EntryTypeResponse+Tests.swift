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

@Suite("Entry Type Response")
struct EntryTypeResponseTests {
    @Test(arguments: [
        EncodeFixture.entryKindResponse(.private, "priv"),
        EncodeFixture.entryKindResponse(.shared, "shared"),
    ])
    func encode(_ fixture: EncodeFixture<EntryKindResponse>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<EntryKindResponse> {
    fileprivate static func entryKindResponse(
        _ input: EntryKindResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntryKindResponse($1) }
        )
    }
}
