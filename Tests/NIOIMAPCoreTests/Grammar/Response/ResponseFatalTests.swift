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

@Suite("ResponseText Fatal")
struct ResponseFatalTests {
    @Test(arguments: [
        EncodeFixture.responseFatal(.init(code: .alert, text: "error"), "* BYE [ALERT] error\r\n"),
        EncodeFixture.responseFatal(.init(code: .serverBug, text: "Oops"), "* BYE [SERVERBUG] Oops\r\n"),
        EncodeFixture.responseFatal(.init(code: nil, text: "Oh, no"), "* BYE Oh, no\r\n"),
    ])
    func encode(_ fixture: EncodeFixture<ResponseText>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ResponseText> {
    fileprivate static func responseFatal(
        _ input: ResponseText,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseFatal($1) }
        )
    }
}
