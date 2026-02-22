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

@Suite("ResponseCodeAppend")
struct ResponseCodeAppendTests {
    @Test(arguments: [
        EncodeFixture.responseCodeAppend(
            .init(uidValidity: 1, uids: [MessageIdentifierRange<UID>(.max)]),
            "APPENDUID 1 *"
        ),
        EncodeFixture.responseCodeAppend(
            .init(uidValidity: 12345, uids: .init(range: 3_599_075...10_565_347)),
            "APPENDUID 12345 3599075:10565347"
        ),
        EncodeFixture.responseCodeAppend(
            .init(uidValidity: 67890, uids: .init(set: [8430, 17553, 19211, 22142])!),
            "APPENDUID 67890 8430,17553,19211,22142"
        )
    ])
    func encode(_ fixture: EncodeFixture<ResponseCodeAppend>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ResponseCodeAppend> {
    fileprivate static func responseCodeAppend(_ input: ResponseCodeAppend, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseCodeAppend($1) }
        )
    }
}
