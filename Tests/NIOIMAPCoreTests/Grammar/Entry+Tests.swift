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
    @Test(arguments: [
        EncodeFixture.entry(.init(key: "name", value: .init("value")), "\"name\" ~{5}\r\nvalue"),
    ])
    func `encode single entry`(_ fixture: EncodeFixture<KeyValue<MetadataEntryName, MetadataValue>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.entryValues(
            ["name": .init("value")],
            "(\"name\" ~{5}\r\nvalue)"
        ),
        EncodeFixture.entryValues(
            ["name1": .init("value1"), "name2": .init("value2")],
            "(\"name1\" ~{6}\r\nvalue1 \"name2\" ~{6}\r\nvalue2)"
        ),
    ])
    func `encode entry values`(_ fixture: EncodeFixture<OrderedDictionary<MetadataEntryName, MetadataValue>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.entries(
            ["name"],
            "(\"name\")"
        ),
        EncodeFixture.entries(
            ["name1", "name2"],
            "(\"name1\" \"name2\")"
        ),
    ])
    func `encode entries list`(_ fixture: EncodeFixture<[MetadataEntryName]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.entryList(
            ["name"],
            "\"name\""
        ),
        EncodeFixture.entryList(
            ["name1", "name2"],
            "\"name1\" \"name2\""
        ),
    ])
    func `encode entry list`(_ fixture: EncodeFixture<[MetadataEntryName]>) {
        fixture.checkEncoding()
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
