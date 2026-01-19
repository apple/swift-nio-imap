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

@Suite("BodyStructure.Encoding")
struct BodyFieldEncodingTests {
    @Test(arguments: [
        EncodeFixture.bodyEncoding(.sevenBit, #""7BIT""#),
        EncodeFixture.bodyEncoding(.eightBit, #""8BIT""#),
        EncodeFixture.bodyEncoding(.binary, #""BINARY""#),
        EncodeFixture.bodyEncoding(.base64, #""BASE64""#),
        EncodeFixture.bodyEncoding(.quotedPrintable, #""QUOTED-PRINTABLE""#),
        EncodeFixture.bodyEncoding(.init("some"), "\"SOME\""),
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.Encoding>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == BodyStructure.Encoding {
    fileprivate static func bodyEncoding(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyEncoding($1) }
        )
    }
}
