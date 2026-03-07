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

@Suite("AppendData")
struct AppendDataTests {
    @Test(arguments: [
        EncodeFixture.appendData(
            .init(byteCount: 123),
            .rfc3501,
            "{123}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 456, withoutContentTransferEncoding: true),
            .rfc3501,
            "~{456}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 123),
            .literalPlus,
            "{123+}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 456, withoutContentTransferEncoding: true),
            .literalPlus,
            "~{456+}\r\n"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AppendData>) {
        fixture.checkEncoding()
    }

    #if swift(>=6.2)
    @Test("encode in server mode calls preconditionFailure")
    func encodeInServerModeCallsPreconditionFailure() async {
        await #expect(
            processExitsWith: ExitTest.Condition.failure,
            performing: {
                var buffer = EncodeBuffer.serverEncodeBuffer(
                    buffer: ByteBufferAllocator().buffer(capacity: 128),
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                buffer.writeAppendData(.init(byteCount: 123))
            }
        )
    }
    #endif

    @Test(arguments: [
        ParseFixture.appendData("{123}\r\n", "hello", expected: .success(.init(byteCount: 123))),
        ParseFixture.appendData(
            "~{456}\r\n",
            "hello",
            expected: .success(.init(byteCount: 456, withoutContentTransferEncoding: true))
        ),
        ParseFixture.appendData("{0}\r\n", "hello", expected: .success(.init(byteCount: 0))),
        ParseFixture.appendData(
            "~{\(Int.max)}\r\n",
            "hello",
            expected: .success(.init(byteCount: .max, withoutContentTransferEncoding: true))
        ),
        ParseFixture.appendData("{123+}\r\n", "hello", expected: .success(.init(byteCount: 123))),
        ParseFixture.appendData(
            "~{456+}\r\n",
            "hello",
            expected: .success(.init(byteCount: 456, withoutContentTransferEncoding: true))
        ),
        ParseFixture.appendData("{0+}\r\n", "hello", expected: .success(.init(byteCount: 0))),
        ParseFixture.appendData(
            "~{\(Int.max)+}\r\n",
            "hello",
            expected: .success(.init(byteCount: .max, withoutContentTransferEncoding: true))
        ),
        ParseFixture.appendData("{-1}\r\n", "hello", expected: .failureIgnoringBufferModifications),
        ParseFixture.appendData("{\(UInt(Int.max) + 1)}\r\n", "hello", expected: .failureIgnoringBufferModifications),
    ])
    func parse(_ fixture: ParseFixture<AppendData>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AppendData> {
    fileprivate static func appendData(
        _ input: AppendData,
        _ options: CommandEncodingOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(options),
            expectedString: expectedString,
            encoder: { $0.writeAppendData($1) }
        )
    }
}

extension ParseFixture<AppendData> {
    fileprivate static func appendData(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAppendData
        )
    }
}
