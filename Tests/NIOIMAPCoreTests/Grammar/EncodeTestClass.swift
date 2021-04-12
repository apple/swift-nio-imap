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

class EncodeTestClass: XCTestCase {
    var testBuffer: _EncodeBuffer!

    var testBufferString: String {
        var remaining: _EncodeBuffer = self.testBuffer
        let nextBit = remaining._nextChunk()._bytes
        return String(buffer: nextBit)
    }

    var testBufferStrings: [String] {
        var remaining: _EncodeBuffer = self.testBuffer
        var chunk = remaining._nextChunk()
        var result: [String] = [String(buffer: chunk._bytes)]
        while chunk._waitForContinuation {
            chunk = remaining._nextChunk()
            result.append(String(buffer: chunk._bytes))
        }
        return result
    }

    override func setUp() {
        self.testBuffer = .serverEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 128), capabilities: [])
    }

    override func tearDown() {
        self.testBuffer = nil
    }

    func iterateInputs<T>(inputs: [(T, String, UInt)], encoder: (T) throws -> Int, file: StaticString = #file) {
        self.iterateInputs(inputs: inputs.map { ($0.0, ResponseEncodingOptions(), $0.1, $0.2) }, encoder: encoder, file: (file))
    }

    func iterateInputs<T>(inputs: [(T, CommandEncodingOptions, [String], UInt)], encoder: (T) throws -> Int, file: StaticString = #file) {
        for (test, options, expectedStrings, line) in inputs {
            self.testBuffer = _EncodeBuffer.clientEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 128), options: options)
            do {
                let size = try encoder(test)
                XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, file: (file), line: line)
                XCTAssertEqual(self.testBufferStrings, expectedStrings, file: (file), line: line)
            } catch {
                XCTFail("\(error)", file: (file), line: line)
            }
        }
    }

    func iterateCommandInputs<T>(inputs: [(T, CommandEncodingOptions, [String], UInt)], encoder: (T) throws -> Int, file: StaticString = #file) {
        for (test, options, expectedStrings, line) in inputs {
            do {
                self.testBuffer.mode = .client(options: options)
                let size = try encoder(test)
                XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, file: (file), line: line)
                XCTAssertEqual(self.testBufferStrings, expectedStrings, file: (file), line: line)
            } catch {
                XCTFail("\(error)", file: (file), line: line)
            }
        }
    }

    func iterateInputs<T>(inputs: [(T, ResponseEncodingOptions, String, UInt)], encoder: (T) throws -> Int, file: StaticString = #file) {
        for (test, options, expectedString, line) in inputs {
            self.testBuffer = _EncodeBuffer.serverEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 128), options: options)
            do {
                let size = try encoder(test)
                XCTAssertEqual(size, expectedString.utf8.count, file: (file), line: line)
                XCTAssertEqual(self.testBufferString, expectedString, file: (file), line: line)
            } catch {
                XCTFail("\(error)", file: (file), line: line)
            }
        }
    }
}

extension CommandEncodingOptions {
    static var rfc3501: CommandEncodingOptions { CommandEncodingOptions() }
    static var literalPlus: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useNonSynchronizingLiteralPlus = true
        return o
    }

    static var literalMinus: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useNonSynchronizingLiteralMinus = true
        return o
    }

    static var noQuoted: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useQuotedString = false
        return o
    }
}

extension ResponseEncodingOptions {
    static var rfc3501: ResponseEncodingOptions { ResponseEncodingOptions() }
}
