//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("InternetMessageDate")
struct InternetMessageDateTests {
    @Test(arguments: [
        EncodeFixture.internetMessageDate(.init("test"), "test"),
    ])
    func encode(_ fixture: EncodeFixture<InternetMessageDate>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<InternetMessageDate> {
    fileprivate static func internetMessageDate(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeInternetMessageDate($1) }
        )
    }
}
