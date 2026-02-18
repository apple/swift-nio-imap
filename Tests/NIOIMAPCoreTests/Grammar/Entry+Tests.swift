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
import Testing
import OrderedCollections
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("Entry")
struct EntryTests {
    @Test("encode single entry", arguments: [
        EncodeFixture.entry(.init(key: "name", value: .init("value")), "\"name\" ~{5}\r\nvalue")
    ])
    func encodeSingleEntry(_ fixture: EncodeFixture<KeyValue<MetadataEntryName, MetadataValue>>) {
        fixture.checkEncoding()
    }

    @Test("encode entry values", arguments: [
        EncodeFixture.entryValues(
            ["name": .init("value")],
            "(\"name\" ~{5}\r\nvalue)"
        ),
        EncodeFixture.entryValues(
            ["name1": .init("value1"), "name2": .init("value2")],
            "(\"name1\" ~{6}\r\nvalue1 \"name2\" ~{6}\r\nvalue2)"
        ),
    ])
    func encodeEntryValues(_ fixture: EncodeFixture<OrderedDictionary<MetadataEntryName, MetadataValue>>) {
        fixture.checkEncoding()
    }

    @Test("encode entries list", arguments: [
        EncodeFixture.entries(
            ["name"],
            "(\"name\")"
        ),
        EncodeFixture.entries(
            ["name1", "name2"],
            "(\"name1\" \"name2\")"
        ),
    ])
    func encodeEntriesList(_ fixture: EncodeFixture<[MetadataEntryName]>) {
        fixture.checkEncoding()
    }

    @Test("encode entry list", arguments: [
        EncodeFixture.entryList(
            ["name"],
            "\"name\""
        ),
        EncodeFixture.entryList(
            ["name1", "name2"],
            "\"name1\" \"name2\""
        ),
    ])
    func encodeEntryList(_ fixture: EncodeFixture<[MetadataEntryName]>) {
        fixture.checkEncoding()
    }

    @Test("parse entry value", arguments: [
        ParseFixture.entryValue(
            "\"name\" \"value\"",
            "",
            expected: .success(.init(key: "name", value: .init("value")))
        ),
        ParseFixture.entryValue(
            "\"name\" NIL",
            "",
            expected: .success(.init(key: "name", value: .init(nil)))
        ),
    ])
    func parseEntryValue(_ fixture: ParseFixture<KeyValue<MetadataEntryName, MetadataValue>>) {
        fixture.checkParsing()
    }

    @Test("parse entry values", arguments: [
        ParseFixture.entryValues(
            "(\"name\" \"value\")",
            "",
            expected: .success(["name": .init("value")])
        ),
        ParseFixture.entryValues(
            "(\"name1\" \"value1\" \"name2\" \"value2\")",
            "",
            expected: .success(["name1": .init("value1"), "name2": .init("value2")])
        ),
    ])
    func parseEntryValues(_ fixture: ParseFixture<OrderedDictionary<MetadataEntryName, MetadataValue>>) {
        fixture.checkParsing()
    }

    @Test("parse entries", arguments: [
        ParseFixture.entries(
            "\"name\"",
            "",
            expected: .success(["name"])
        ),
        ParseFixture.entries(
            "(\"name\")",
            "",
            expected: .success(["name"])
        ),
        ParseFixture.entries(
            "(\"name1\" \"name2\")",
            "",
            expected: .success(["name1", "name2"])
        ),
    ])
    func parseEntries(_ fixture: ParseFixture<[MetadataEntryName]>) {
        fixture.checkParsing()
    }

    @Test("parse entry list", arguments: [
        ParseFixture.entryList(
            "\"name\"",
            expected: .success(["name"])
        ),
        ParseFixture.entryList(
            "\"name1\" \"name2\"",
            expected: .success(["name1", "name2"])
        ),
    ])
    func parseEntryList(_ fixture: ParseFixture<[MetadataEntryName]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<MetadataEntryName, MetadataValue>> {
    fileprivate static func entry(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntry($1) }
        )
    }
}

extension EncodeFixture<OrderedDictionary<MetadataEntryName, MetadataValue>> {
    fileprivate static func entryValues(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntryValues($1) }
        )
    }
}

extension EncodeFixture<[MetadataEntryName]> {
    fileprivate static func entries(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntries($1) }
        )
    }

    fileprivate static func entryList(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntryList($1) }
        )
    }
}

extension ParseFixture<KeyValue<MetadataEntryName, MetadataValue>> {
    fileprivate static func entryValue(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntryValue
        )
    }
}

extension ParseFixture<OrderedDictionary<MetadataEntryName, MetadataValue>> {
    fileprivate static func entryValues(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntryValues
        )
    }
}

extension ParseFixture<[MetadataEntryName]> {
    fileprivate static func entries(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntries
        )
    }

    fileprivate static func entryList(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntryList
        )
    }
}
