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

@Suite("UntaggedStatus")
struct UntaggedStatusTests {
    @Test(arguments: [
        EncodeFixture.untaggedStatus(.ok(.init(code: .alert, text: "error")), "OK [ALERT] error"),
        EncodeFixture.untaggedStatus(.no(.init(code: .readOnly, text: "everything")), "NO [READ-ONLY] everything"),
        EncodeFixture.untaggedStatus(.bad(.init(code: .parse, text: "something")), "BAD [PARSE] something"),
        EncodeFixture.untaggedStatus(.preauth(.init(code: .capability([.uidPlus]), text: "logged in as Smith")), "PREAUTH [CAPABILITY UIDPLUS] logged in as Smith"),
        EncodeFixture.untaggedStatus(.bye(.init(code: .alert, text: "Autologout; idle for too long")), "BYE [ALERT] Autologout; idle for too long"),
        EncodeFixture.untaggedStatus(.ok(.init(text: "error")), "OK error"),
        EncodeFixture.untaggedStatus(.no(.init(text: "everything")), "NO everything"),
        EncodeFixture.untaggedStatus(.bad(.init(text: "something")), "BAD something"),
        EncodeFixture.untaggedStatus(.preauth(.init(text: "logged in as Smith")), "PREAUTH logged in as Smith"),
        EncodeFixture.untaggedStatus(.bye(.init(text: "Autologout; idle for too long")), "BYE Autologout; idle for too long"),
    ])
    func encode(_ fixture: EncodeFixture<UntaggedStatus>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<UntaggedStatus> {
    fileprivate static func untaggedStatus(_ input: UntaggedStatus, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUntaggedStatus($1) }
        )
    }
}
