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
import NIOTestUtils
import XCTest

final class SynchronizingLiteralParserTests: XCTestCase {
    var parser: SynchronizingLiteralParser!
    var parses: [SynchronizingLiteralParser.FramingResult] = []
    var accumulator: ByteBuffer!
    var consumptions: [(numberOfPriorParses: Int, consumption: Int)] = []

    func testStraightForwardCase() {
        let string = "LOGIN \"a\" \"b\"\r\nFOO x y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 0)
    }

    func testEmptyLiteralsWork() {
        let string = "LOGIN {0}\r\n {0+}\r\n {~0}\r\n {~0+}\r\n {0-}\r\n\r\nFOO x y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 2)
    }

    func testStraightForwardCaseWithSynchronisingLiterals() {
        let string = "LOGIN {1}\r\nA {1}\r\nB\r\nFOO x y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 2)
    }

    func testStraightForwardCaseWithNonSynchronisingLiterals() {
        let string = "LOGIN {1+}\r\nA {1+}\r\nB\r\nFOO x y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 0)
    }

    func testStraightForwardCaseWithMixedLiterals() {
        let string = "LOGIN {1+}\r\nA {1}\r\nB\r\nFOO x y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 1)
    }

    func testPartialCommandsDontMakeBytesVisible() {
        let string = "LOGIN \"a\" \"b\"\r"
        self.feed(string)
        self.assertOneParse("", continuationsNecessary: 0)
    }

    func testPartialCommandsLiteralsDoMakeBytesVisible1() {
        let string = "LOGIN \"a\" {2}\r\n1"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 1)
    }

    func testPartialCommandsLiteralsDoMakeBytesVisible2() {
        let string = "LOGIN \"a\" {2}\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 1)
    }

    func testDripFeedWorksForLiterals() {
        self.feed("LOGIN {")
        self.feed("1")
        self.feed("}")
        self.feed("\r")
        XCTAssertEqual(0, self.parses.last?.synchronizingLiteralCount ?? -1)
        self.feed("\n")
        XCTAssertEqual(1, self.parses.last?.synchronizingLiteralCount ?? -1)
        self.assertMultipleParses(["", "", "", "", "LOGIN {1}\r\n"], continuationsNecessary: 1)
    }

    func testLiteralDataInNormalLiteral() {
        let string = "{5}\r\n{0}\r\n\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 1)
    }

    func testLiteralDataInPlusLiteral() {
        let string = "{5+}\r\n{0}\r\n\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 0)
    }

    func testConsumptionWorks() {
        let string = "LOGIN {1}\r\nA {1}\r\nB\r\nFOO {1}\r\nx y\r\n"
        self.feed(string)
        self.assertOneParse(string, continuationsNecessary: 3)
        self.indicateConsume("LOGIN {1}\r\nA {1}\r\n")
        self.feed("")
        self.indicateConsume("B")
        self.feed("")
        self.indicateConsume("\r\n")
        self.feed("")
        self.indicateConsume("FOO {1}\r\nx y\r\n")
        self.assertMultipleParses([
            "LOGIN {1}\r\nA {1}\r\nB\r\nFOO {1}\r\nx y\r\n",
            "B\r\nFOO {1}\r\nx y\r\n",
            "\r\nFOO {1}\r\nx y\r\n",
            "FOO {1}\r\nx y\r\n",
        ], continuationsNecessary: 3)
    }

    func testDripFeedWorks() {
        self.feed("LOGIN {")
        self.feed("1}\r")
        self.feed("\n")
        self.feed("\n")
        self.feed("\n")
        self.feed("LOGIN {")
        self.feed("1}\r")
        self.feed("\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n")
        self.indicateConsume("LOGIN {1}\r\n\n\n")
        self.feed("")
        self.indicateConsume("LOGIN {1}\r\n")
        self.feed("")
        self.indicateConsume(" ")
        self.feed("")
        self.indicateConsume("{2}\r\n")
        self.feed("")
        self.indicateConsume("\n\n")
        self.feed("")
        self.indicateConsume("FOO {5}\n{0}\r\n\n")
        self.feed("")

        self.assertMultipleParses([
            "",
            "",
            "LOGIN {1}\r\n",
            "LOGIN {1}\r\n\n",
            "LOGIN {1}\r\n\n\n",
            "LOGIN {1}\r\n\n\n",
            "LOGIN {1}\r\n\n\n",
            "LOGIN {1}\r\n\n\nLOGIN {1}\r\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
            "LOGIN {1}\r\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
            " {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
            "{2}\n\r\n\nFOO {5}\n{0}\r\n\n",
            "\n\nFOO {5}\n{0}\r\n\n",
            "FOO {5}\n{0}\r\n\n",
            "",
        ], continuationsNecessary: 4)
    }

    func testAppendFollowedByHalfCommand() {
        self.feed("tag APPEND box (\\Seen) {1+}\r\na\r\n")
        self.indicateConsume("tag APPEND box (\\Seen) {1+}\r\n")
        self.feed("")
        self.indicateConsume("a")
        self.feed("")
        self.feed("t")

        self.assertMultipleParses(["tag APPEND box (\\Seen) {1+}\r\na\r\n",
                                   "a\r\n",
                                   "\r\n",
                                   "\r\n"])
    }

    override func setUp() {
        XCTAssertNil(self.accumulator)
        XCTAssertNil(self.parser)
        XCTAssertEqual(0, self.parses.count)
        XCTAssertEqual(0, self.consumptions.count)
        self.parser = SynchronizingLiteralParser()
        self.accumulator = self.stringBuffer("")
    }

    override func tearDown() {
        XCTAssertNotNil(self.parser)
        XCTAssertNotNil(self.accumulator)
        self.parses = []
        self.parser = nil
        self.accumulator = nil
        self.consumptions = []
    }

    private func feed(_ string: String) {
        let buffer = self.stringBuffer(string)
        self.accumulator.writeBytes(buffer.readableBytesView)
        XCTAssertNoThrow(self.parses.append(try self.parser.parseContinuationsNecessary(self.bufferWithGarbage(self.accumulator))))
    }

    private func indicateConsume(_ string: String) {
        self.consumptions.append((self.parses.count, string.utf8.count))
        self.accumulator.moveReaderIndex(forwardBy: string.utf8.count)
        self.parser.consumed(string.utf8.count)
    }

    private func assertMultipleParses(_ expectedStrings: [String], continuationsNecessary: Int = 0,
                                      file: StaticString = (#file),
                                      line: UInt = #line) {
        guard expectedStrings.count == self.parses.count else {
            XCTFail("Unexpected number of parses: \(self.parses.count)", file: file, line: line)
            return
        }

        var allBytes = self.accumulator!
        let initialAllByteReader = self.accumulator.readerIndex - self.consumptions.map { $0.consumption }.reduce(0, +)
        allBytes.moveReaderIndex(to: initialAllByteReader)
        var continuations = 0
        for expected in expectedStrings.enumerated() {
            let parse = self.parses[expected.offset]
            let expectedUTF8 = Array(expected.element.utf8)
            let actual = Array(allBytes.readableBytesView.prefix(parse.maximumValidBytes))
            XCTAssertEqual(expectedUTF8, actual,
                           "parse \(expected.0): \(String(decoding: expectedUTF8, as: UTF8.self)) != \(String(decoding: actual, as: UTF8.self))",
                           file: file, line: line)
            XCTAssertGreaterThanOrEqual(parse.synchronizingLiteralCount, 0)
            continuations += parse.synchronizingLiteralCount

            let newReader = self.consumptions.filter {
                $0.numberOfPriorParses <= expected.offset + 1
            }.map { $0.consumption }.reduce(0, +) + initialAllByteReader
            allBytes.moveReaderIndex(to: newReader)
        }
        XCTAssertEqual(continuationsNecessary, continuations,
                       "wrong number of continuations",
                       file: file, line: line)
    }

    private func assertOneParse(_ string: String, continuationsNecessary: Int = 0,
                                file: StaticString = (#file),
                                line: UInt = #line) {
        XCTAssertEqual(1, self.parses.count)
        guard let parse = self.parses.first else {
            XCTFail("no parses found", file: file, line: line)
            return
        }
        let expected = Array(string.utf8)
        let actual = Array(self.accumulator.readableBytesView.prefix(parse.maximumValidBytes))
        XCTAssertEqual(expected, actual,
                       "\(String(decoding: expected, as: UTF8.self)) != \(String(decoding: actual, as: UTF8.self))",
                       file: file, line: line)
        XCTAssertEqual(continuationsNecessary, parse.synchronizingLiteralCount,
                       file: file, line: line)
    }

    private func stringBuffer(_ string: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return self.bufferWithGarbage(buffer)
    }

    private func bufferWithGarbage(_ buffer: ByteBuffer) -> ByteBuffer {
        var buffer = buffer
        let garbageByteCount = (0 ..< 32).randomElement() ?? 0
        var newBuffer = ByteBufferAllocator().buffer(capacity: garbageByteCount + buffer.readableBytes)
        newBuffer.writeString(String(repeating: "X", count: garbageByteCount))
        newBuffer.moveReaderIndex(forwardBy: garbageByteCount)
        newBuffer.writeBuffer(&buffer)
        return newBuffer
    }
}
