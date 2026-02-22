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
        EncodeFixture.storeFlags(.replace(silent: false, list: [.deleted]), "FLAGS (\\Deleted)")
    ])
    func encode(_ fixture: EncodeFixture<StoreFlags>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.storeFlags("+FLAGS ()", expected: .success(.add(silent: false, list: []))),
        ParseFixture.storeFlags("-FLAGS ()", expected: .success(.remove(silent: false, list: []))),
        ParseFixture.storeFlags("FLAGS ()", expected: .success(.replace(silent: false, list: []))),
        ParseFixture.storeFlags("+FLAGS.SILENT ()", expected: .success(.add(silent: true, list: []))),
        ParseFixture.storeFlags(
            #"+FLAGS.SILENT (\answered \seen)"#,
            expected: .success(.add(silent: true, list: [.answered, .seen]))
        ),
        ParseFixture.storeFlags(
            #"+FLAGS.SILENT \answered \seen"#,
            expected: .success(.add(silent: true, list: [.answered, .seen]))
        ),
        ParseFixture.storeFlags(#"FLAGS.SILEN \answered"#, expected: .failure),
        ParseFixture.storeFlags("+FLAGS ", "", expected: .incompleteMessage),
        ParseFixture.storeFlags("-FLAGS ", "", expected: .incompleteMessage),
        ParseFixture.storeFlags("FLAGS ", "", expected: .incompleteMessage)
    ])
    func parse(_ fixture: ParseFixture<StoreFlags>) {
        fixture.checkParsing()
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

extension ParseFixture<StoreFlags> {
    fileprivate static func storeFlags(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreFlags
        )
    }
}
