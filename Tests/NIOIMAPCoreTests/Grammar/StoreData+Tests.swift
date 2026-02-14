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

@Suite("StoreData")
struct StoreDataTests {
    @Test(arguments: [
        ParseFixture.storeModifier("UNCHANGEDSINCE 2", expected: .success(.unchangedSince(.init(modificationSequence: 2)))),
        ParseFixture.storeModifier("test", "\r", expected: .success(.other(.init(key: "test", value: nil)))),
        ParseFixture.storeModifier("test 1", expected: .success(.other(.init(key: "test", value: .sequence(.set([1])))))),
        ParseFixture.storeModifier("1", expected: .failure),
        ParseFixture.storeModifier("UNCHANGEDSINCE 1", "", expected: .incompleteMessage),
        ParseFixture.storeModifier("test 1", "", expected: .incompleteMessage),
    ])
    func `parse store modifier`(_ fixture: ParseFixture<StoreModifier>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.storeData("+FLAGS (foo)", expected: .success(.flags(.add(silent: false, list: [.init("foo")])))),
        ParseFixture.storeData("-X-GM-LABELS (bar)", expected: .success(.gmailLabels(.remove(silent: false, gmailLabels: [.init("bar")])))),
        ParseFixture.storeData(#"+SOMETHING \answered"#, expected: .failure),
        ParseFixture.storeData("+", "", expected: .incompleteMessage),
        ParseFixture.storeData("-", "", expected: .incompleteMessage),
        ParseFixture.storeData("", "", expected: .incompleteMessage),
    ])
    func `parse store data`(_ fixture: ParseFixture<StoreData>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.storeGmailLabels("+X-GM-LABELS (foo)", expected: .success(.add(silent: false, gmailLabels: [.init("foo")]))),
        ParseFixture.storeGmailLabels("-X-GM-LABELS (foo bar)", expected: .success(.remove(silent: false, gmailLabels: [.init("foo"), .init("bar")]))),
        ParseFixture.storeGmailLabels("X-GM-LABELS (foo bar boo far)", expected: .success(.replace(silent: false, gmailLabels: [.init("foo"), .init("bar"), .init("boo"), .init("far")]))),
        ParseFixture.storeGmailLabels("X-GM-LABELS.SILENT (foo)", expected: .success(.replace(silent: true, gmailLabels: [.init("foo")]))),
        ParseFixture.storeGmailLabels("+X-GM-LABEL.SILEN (foo)", expected: .failure),
        ParseFixture.storeGmailLabels("+X-GM-LABELS ", "", expected: .incompleteMessage),
        ParseFixture.storeGmailLabels("-X-GM-LABELS ", "", expected: .incompleteMessage),
        ParseFixture.storeGmailLabels("X-GM-LABELS ", "", expected: .incompleteMessage),
    ])
    func `parse store gmail labels`(_ fixture: ParseFixture<StoreGmailLabels>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<StoreModifier> {
    fileprivate static func storeModifier(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreModifier
        )
    }
}

extension ParseFixture<StoreData> {
    fileprivate static func storeData(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreData
        )
    }
}

extension ParseFixture<StoreGmailLabels> {
    fileprivate static func storeGmailLabels(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStoreGmailLabels
        )
    }
}
