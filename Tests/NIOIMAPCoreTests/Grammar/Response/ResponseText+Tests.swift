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

@Suite("ResponseText")
struct ResponseTextTests {
    @Test(arguments: [
        EncodeFixture.responseText(.init(code: nil, text: "buffer"), "buffer"),
        EncodeFixture.responseText(.init(code: .alert, text: "buffer"), "[ALERT] buffer"),
        EncodeFixture.responseText(.init(code: nil, text: ""), " "),
        EncodeFixture.responseText(.init(code: .alert, text: ""), "[ALERT]  "),
    ])
    func encode(_ fixture: EncodeFixture<ResponseText>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        DebugStringFixture(sut: ResponseText(code: nil, text: "buffer"), expected: "buffer"),
        DebugStringFixture(sut: ResponseText(code: .alert, text: "buffer"), expected: "[ALERT] buffer"),
    ])
    func `custom debug string convertible`(_ fixture: DebugStringFixture<ResponseText>) {
        fixture.check()
    }
}

// MARK: -

extension EncodeFixture<ResponseText> {
    fileprivate static func responseText(
        _ input: ResponseText,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseText($1) }
        )
    }
}
