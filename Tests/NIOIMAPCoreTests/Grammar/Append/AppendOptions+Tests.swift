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

extension EncodeFixture<AppendOptions> {
    fileprivate static func appendOptions(
        _ input: AppendOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(.rfc3501),
            expectedStrings: [expectedString],
            encoder: { $0.writeAppendOptions($1) }
        )
    }
}

@Suite("AppendOptions")
struct AppendOptionsTests {
    @Test(arguments: [
        EncodeFixture.appendOptions(
            .none,
            ""
        ),
        EncodeFixture.appendOptions(
            .init(flagList: [.answered], internalDate: nil, extensions: [:]),
            " (\\Answered)"
        ),
        EncodeFixture.appendOptions(
            .init(
                flagList: [.answered],
                internalDate: ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1994,
                        month: 6,
                        day: 25,
                        hour: 1,
                        minute: 2,
                        second: 3,
                        timeZoneMinutes: 0
                    )!
                ),
                extensions: [:]
            ),
            " (\\Answered) \"25-Jun-1994 01:02:03 +0000\""
        ),
    ])
    func encode(_ fixture: EncodeFixture<AppendOptions>) {
        fixture.checkEncoding()
    }
}
