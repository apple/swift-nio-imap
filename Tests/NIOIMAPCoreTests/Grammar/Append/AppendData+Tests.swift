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

extension EncodeFixture<AppendData> {
    fileprivate static func appendData(
        _ input: AppendData,
        _ options: CommandEncodingOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(options),
            expectedStrings: [expectedString],
            encoder: { $0.writeAppendData($1) }
        )
    }
}

@Suite("AppendData")
struct AppendDataTests {
    @Test(arguments: [
        EncodeFixture.appendData(
            .init(byteCount: 123), .rfc3501, "{123}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 456, withoutContentTransferEncoding: true), .rfc3501, "~{456}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 123), .literalPlus, "{123+}\r\n"
        ),
        EncodeFixture.appendData(
            .init(byteCount: 456, withoutContentTransferEncoding: true), .literalPlus, "~{456+}\r\n"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AppendData>) {
        fixture.checkEncoding()
    }
}
