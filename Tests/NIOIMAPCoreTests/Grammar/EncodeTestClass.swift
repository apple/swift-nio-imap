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
    var testBuffer: EncodeBuffer!

    var testBufferString: String {
        var remaining: EncodeBuffer = self.testBuffer
        let nextBit = remaining.nextChunk().bytes
        return String(buffer: nextBit)
    }

    var testBufferStrings: [String] {
        var remaining: EncodeBuffer = self.testBuffer
        var chunk = remaining.nextChunk()
        var result: [String] = [String(buffer: chunk.bytes)]
        while chunk.waitForContinuation {
            chunk = remaining.nextChunk()
            result.append(String(buffer: chunk.bytes))
        }
        return result
    }

    override func setUp() {
        self.resetTestBuffer(ResponseEncodingOptions())
    }

    override func tearDown() {
        self.testBuffer = nil
    }

    func resetTestBuffer(_ options: CommandEncodingOptions) {
        self.testBuffer = EncodeBuffer.clientEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 200), options: options)
    }

    func resetTestBuffer(_ options: ResponseEncodingOptions) {
        self.testBuffer = EncodeBuffer.serverEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 200), options: options)
    }
  
    func iterateInputs<T>(inputs: [(T, String, UInt)], encoder: (T) throws -> Int, file: StaticString = (#file)) {
        self.iterateInputs(inputs: inputs.map { ($0.0, ResponseEncodingOptions(), $0.1, $0.2) }, encoder: encoder, file: file)
    }

    func iterateInputs<T>(inputs: [(T, CommandEncodingOptions, [String], UInt)], encoder: (T) throws -> Int, file: StaticString = (#file)) {
        for (test, options, expectedStrings, line) in inputs {
            self.resetTestBuffer(options)
            do {
                let size = try encoder(test)
                XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, file: file, line: line)
                XCTAssertEqual(self.testBufferStrings, expectedStrings, file: file, line: line)
            } catch {
                XCTFail("\(error)", file: file, line: line)
            }
        }
    }

    func iterateCommandInputs<T>(inputs: [(T, CommandEncodingOptions, [String], UInt)], encoder: (T) throws -> Int, file: StaticString = (#file)) {
        for (test, options, expectedStrings, line) in inputs {
            do {
                self.testBuffer.mode = .client(options: options)
                let size = try encoder(test)
                XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, file: file, line: line)
                XCTAssertEqual(self.testBufferStrings, expectedStrings, file: file, line: line)
            } catch {
                XCTFail("\(error)", file: file, line: line)
            }
        }
    }

    func iterateInputs<T>(inputs: [(T, ResponseEncodingOptions, String, UInt)], encoder: (T) throws -> Int, file: StaticString = (#file)) {
        for (test, options, expectedString, line) in inputs {
            self.resetTestBuffer(options)
            do {
                let size = try encoder(test)
                XCTAssertEqual(size, expectedString.utf8.count, file: file, line: line)
                XCTAssertEqual(self.testBufferString, expectedString, file: file, line: line)
            } catch {
                XCTFail("\(error)", file: file, line: line)
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

extension EncodeTestClass {
    func roundTrip<T>(value: T, suffix: String? = nil, encode: (inout EncodeBuffer, T) -> Void, decode: (inout ByteBuffer) throws -> T) throws -> T {
        var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: ByteBufferAllocator().buffer(capacity: 200), options: CommandEncodingOptions())
        encode(&encodeBuffer, value)
        if let s = suffix {
            encodeBuffer.writeString(s)
        }
        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        while true {
            let next = encodeBuffer.nextChunk()
            var toSend = next.bytes
            buffer.writeBuffer(&toSend)
            if !next.waitForContinuation {
                break
            }
        }
        defer {
            buffer.clear()
        }
        let result = try decode(&buffer)
        if let s = suffix {
            guard buffer.readableBytes == s.count else {
                throw RoundTripError.readableBytesWrong(buffer.readableBytes, s.count)
            }
            guard let decodedSuffix = buffer.readString(length: s.count) else {
                throw RoundTripError.suffixDoesNotMatch(nil, s)
            }
            guard decodedSuffix == suffix else {
                throw RoundTripError.suffixDoesNotMatch(decodedSuffix, s)
            }
        } else {
            guard buffer.readableBytes == 0 else {
                throw RoundTripError.readableBytesWrong(buffer.readableBytes, 0)
            }
        }
        return result
    }

    enum RoundTripError: Swift.Error {
        case suffixDoesNotMatch(String?, String)
        case readableBytesWrong(Int, Int)
    }
}
