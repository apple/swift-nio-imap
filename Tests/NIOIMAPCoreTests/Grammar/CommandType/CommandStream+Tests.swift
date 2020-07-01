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

class CommandStream_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandStream_Tests {
    func testEncode() {
        let inputs: [(AppendCommand, String, UInt)] = [
            (.start(tag: "1", appendingTo: .inbox), "1 APPEND \"INBOX\"", #line),
            (
                .beginMessage(messsage: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 3))),
                " {3}\r\n",
                #line
            ),
            (
                .beginMessage(messsage: .init(options: .init(flagList: [.seen, .deleted], extensions: []), data: .init(byteCount: 3))),
                " (\\Seen \\Deleted) {3}\r\n",
                #line
            ),
            (.messageBytes("123"), "123", #line),
            (.endMessage, "", #line), // dummy command, we don't expect anything
            (.finish, "\r\n", #line),
        ]

        for (command, expected, line) in inputs {
            var commandEncodeBuffer = CommandEncodeBuffer(buffer: "", capabilities: [])
            XCTAssertNoThrow(try commandEncodeBuffer.writeAppendCommand(command), line: line)
            XCTAssertEqual(String(buffer: commandEncodeBuffer.buffer._buffer), expected, line: line)
        }
    }

    func testContinuation_synchronizing() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(messsage: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 7))),
            .messageBytes("Foo Bar"),
            .endMessage,
            .finish,
        ]

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [])
        try parts.forEach {
            try buffer.writeAppendCommand($0)
        }

        let encodedCommand = buffer.buffer.nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand.bytes), #"1 APPEND "INBOX" {7}\#r\#n"#)
        guard encodedCommand.waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }
        let continuation = buffer.buffer.nextChunk()
        XCTAssertEqual(String(buffer: continuation.bytes), "Foo Bar\r\n")
        XCTAssertFalse(continuation.waitForContinuation, "Should not have additional continuations.")
    }

    func testContinuation_nonSynchronizing() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(messsage: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 3, synchronizing: false))),
            .messageBytes("abc"),
            .endMessage,
            .finish,
        ]

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [.nonSynchronizingLiterals])
        try parts.forEach {
            try buffer.writeAppendCommand($0)
        }

        let encodedCommand = buffer.buffer.nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand.bytes), #"1 APPEND "INBOX" {3+}\#r\#nabc\#r\#n"#)
        guard !encodedCommand.waitForContinuation else {
            XCTFail("Should not have had a continuation.")
            return
        }
    }
}
