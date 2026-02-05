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

@Suite("StoreFlags")
struct StoreAttributeFlagsTests {
    @Test(arguments: [
        EncodeFixture.storeFlags(.add(silent: true, list: [.answered]), "+FLAGS.SILENT (\\Answered)"),
        EncodeFixture.storeFlags(.add(silent: false, list: [.draft]), "+FLAGS (\\Draft)"),
        EncodeFixture.storeFlags(.remove(silent: true, list: [.deleted]), "-FLAGS.SILENT (\\Deleted)"),
        EncodeFixture.storeFlags(.remove(silent: false, list: [.flagged]), "-FLAGS (\\Flagged)"),
        EncodeFixture.storeFlags(.replace(silent: true, list: [.seen]), "FLAGS.SILENT (\\Seen)"),
        EncodeFixture.storeFlags(.replace(silent: false, list: [.deleted]), "FLAGS (\\Deleted)"),
    ])
    func encode(_ fixture: EncodeFixture<StoreFlags>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<StoreFlags> {
    fileprivate static func storeFlags(_ input: StoreFlags, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeStoreAttributeFlags($1) }
        )
    }
}
