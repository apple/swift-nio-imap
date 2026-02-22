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

extension ByteBuffer {
    fileprivate init(_ bytes: [UInt8]) {
        self.init()
        writeBytes(bytes)
    }
}

private let bufferA = ByteBuffer([
    0x60, 0x33, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x12, 0x01, 0x02,
    0x02, 0x02, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xEA, 0x37, 0x32,
    0x1B, 0x81, 0x84, 0xDC, 0xA9, 0x13, 0xCC, 0x17, 0x81, 0x89, 0x51, 0xDE,
    0x71, 0xE3, 0xF6, 0x09, 0x66, 0x34, 0x49, 0x1D, 0x1F, 0x01, 0x00, 0x20,
    0x00, 0x04, 0x04, 0x04, 0x04
])

@Suite("ContinuationRequest")
struct ContinuationRequestTests {
    @Test(arguments: [
        EncodeFixture.continuationRequest(.responseText(.init(text: ".")), "+ .\r\n"),
        EncodeFixture.continuationRequest(.responseText(.init(text: "Ok. Foo")), "+ Ok. Foo\r\n"),
        EncodeFixture.continuationRequest(.responseText(.init(code: .alert, text: "text")), "+ [ALERT] text\r\n"),
        EncodeFixture.continuationRequest(.data("a"), "+ YQ==\r\n"),
        EncodeFixture.continuationRequest(
            .data(bufferA),
            "+ YDMGCSqGSIb3EgECAgIBAAD/////6jcyG4GE3KkTzBeBiVHeceP2CWY0SR0fAQAgAAQEBAQ=\r\n"
        )
    ])
    func encode(_ fixture: EncodeFixture<ContinuationRequest>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.continuationRequest("+ .\r\n", expected: .success(.responseText(.init(text: ".")))),
        ParseFixture.continuationRequest("+ Ok. Foo\r\n", expected: .success(.responseText(.init(text: "Ok. Foo")))),
        ParseFixture.continuationRequest("+ OK\r\n", expected: .success(.responseText(.init(text: "OK")))),
        ParseFixture.continuationRequest(
            "+ IDLE accepted, awaiting DONE command.\r\n",
            expected: .success(.responseText(.init(text: "IDLE accepted, awaiting DONE command.")))
        ),
        ParseFixture.continuationRequest(
            "+ Ready for additional command text\r\n",
            expected: .success(.responseText(.init(text: "Ready for additional command text")))
        ),
        ParseFixture.continuationRequest("+ \r\n", expected: .success(.responseText(.init(text: "")))),
        ParseFixture.continuationRequest("+\r\n", expected: .success(.responseText(.init(text: "")))),
        ParseFixture.continuationRequest(
            "+ [ALERT] text\r\n",
            expected: .success(.responseText(.init(code: .alert, text: "text")))
        ),
        ParseFixture.continuationRequest("+ YQ==\r\n", expected: .success(.data("a"))),
        ParseFixture.continuationRequest(
            "+ YDMGCSqGSIb3EgECAgIBAAD/////6jcyG4GE3KkTzBeBiVHeceP2CWY0SR0fAQAgAAQEBAQ=\r\n",
            expected: .success(.data(bufferA))
        )
    ])
    func parse(_ fixture: ParseFixture<ContinuationRequest>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ContinuationRequest> {
    fileprivate static func continuationRequest(
        _ input: ContinuationRequest,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .server(ResponseEncodingOptions()),
            expectedString: expectedString,
            encoder: {
                var encoder = ResponseEncodeBuffer(
                    buffer: $0.buffer,
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                let count = encoder.writeContinuationRequest($1)
                $0 = encoder.buffer
                return count
            }
        )
    }
}

extension ParseFixture<ContinuationRequest> {
    fileprivate static func continuationRequest(
        _ input: String,
        _ terminator: String = "A",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseContinuationRequest
        )
    }
}
