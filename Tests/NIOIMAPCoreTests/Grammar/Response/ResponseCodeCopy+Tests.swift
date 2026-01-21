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

@Suite("ResponseCodeCopy")
struct ResponseCodeCopyTests {
    @Test(arguments: [
        EncodeFixture.responseCodeCopy(.init(destinationUIDValidity: 1, sourceUIDs: [MessageIdentifierRange<UID>(.max)], destinationUIDs: [MessageIdentifierRange<UID>(.max)]), "COPYUID 1 * *"),
        EncodeFixture.responseCodeCopy(.init(destinationUIDValidity: 4_294_967_295, sourceUIDs: [MessageIdentifierRange<UID>(1...5)], destinationUIDs: [MessageIdentifierRange<UID>(10...14)]), "COPYUID 4294967295 1:5 10:14"),
        EncodeFixture.responseCodeCopy(.init(destinationUIDValidity: 917_162_500, sourceUIDs: [MessageIdentifierRange<UID>(1), MessageIdentifierRange<UID>(3), MessageIdentifierRange<UID>(5...7)], destinationUIDs: [MessageIdentifierRange<UID>(2), MessageIdentifierRange<UID>(4), MessageIdentifierRange<UID>(6...8)]), "COPYUID 917162500 1,3,5:7 2,4,6:8"),
    ])
    func encode(_ fixture: EncodeFixture<ResponseCodeCopy>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ResponseCodeCopy> {
    fileprivate static func responseCodeCopy(_ input: ResponseCodeCopy, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseCodeCopy($1) }
        )
    }
}
