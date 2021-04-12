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

import OrderedCollections
import NIO
@testable import NIOIMAPCore
import XCTest

class Entry_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Entry_Tests {
    func testEncode() {
        let inputs: [(KeyValue<ByteBuffer, MetadataValue>, String, UInt)] = [
            (.init(key: "name", value: .init("value")), "\"name\" ~{5}\r\nvalue", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEntry($0) })
    }

    func testEncode_entryValues() {
        let inputs: [(OrderedDictionary<ByteBuffer, MetadataValue>, String, UInt)] = [
            (
                ["name": .init("value")],
                "(\"name\" ~{5}\r\nvalue)",
                #line
            ),
            (
                ["name1": .init("value1"), "name2": .init("value2")],
                "(\"name1\" ~{6}\r\nvalue1 \"name2\" ~{6}\r\nvalue2)",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEntryValues($0) })
    }

    func testEncode_entries() {
        let inputs: [([ByteBuffer], String, UInt)] = [
            (
                ["name"],
                "(\"name\")",
                #line
            ),
            (
                ["name1", "name2"],
                "(\"name1\" \"name2\")",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEntries($0) })
    }

    func testEncode_entryList() {
        let inputs: [([ByteBuffer], String, UInt)] = [
            (
                ["name"],
                "\"name\"",
                #line
            ),
            (
                ["name1", "name2"],
                "\"name1\" \"name2\"",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEntryList($0) })
    }
}
