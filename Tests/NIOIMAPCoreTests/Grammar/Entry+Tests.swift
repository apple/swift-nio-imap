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
@testable import NIOIMAPCore
import XCTest

class Entry_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Entry_Tests {
    func testEncode() {
        let inputs: [(EntryValue, String, UInt)] = [
            (.init(name: "name", value: .init(rawValue: "value")), "\"name\" ~{5}\r\nvalue", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEntry($0) })
    }
    
    func testEncode_entryValues() {
        let inputs: [([EntryValue], String, UInt)] = [
            (
                [.init(name: "name", value: .init(rawValue: "value"))],
                "(\"name\" ~{5}\r\nvalue)",
                #line
            ),
            (
                [.init(name: "name1", value: .init(rawValue: "value1")), .init(name: "name2", value: .init(rawValue: "value2"))],
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
