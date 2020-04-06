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

import XCTest
import NIO
@testable import NIOIMAP

final class IMAPFramingParserTests: XCTestCase {
    var parses: [ByteBuffer] = []
    var continuationsParsed = 0
    var parser: IMAPFramingParser! = nil

    override func setUp() {
        XCTAssertNil(self.parser)
        XCTAssertEqual(0, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.parser = IMAPFramingParser(bufferSizeLimit: 100)
    }

    override func tearDown() {
        XCTAssertNotNil(self.parser)
        self.parser = nil
        self.parses = []
        self.continuationsParsed = 0
    }

    func feedAllowingErrors(_ string: String) throws {
        var buffer = self.stringBuffer(string)
        repeat {
            let result = try self.parser.parse(&buffer)
            self.continuationsParsed += result.numberOfContinuationRequestsToSend
            if let line = result.line {
                self.parses.append(line)
            } else {
                break
            }
        } while true
    }

    func feed(_ string: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNoThrow(try self.feedAllowingErrors(string), file: file, line: line)
    }

    func testBasicLine() {
        self.feed("a001 LOGIN")
        XCTAssert(self.parses.isEmpty)
        self.feed(#" "hello" "you""#)
        XCTAssert(self.parses.isEmpty)
        self.feed("\r")
        XCTAssert(self.parses.isEmpty)
        self.feed("\n")
        self.assertOneParse(#"a001 LOGIN "hello" "you""# + "\r\n")
    }

    func testBasicLineNoCR() {
        self.feed("a001 LOGIN")
        XCTAssert(self.parses.isEmpty)
        self.feed(#" "hello" "you""#)
        XCTAssert(self.parses.isEmpty)
        self.feed("\n")
        self.assertOneParse(#"a001 LOGIN "hello" "you""# + "\n")
    }

    func testTwoLinesInOne() {
        self.feed(#"a001 LOGIN "hello" "you""# + "\r\n" + #"a002 LOGIN "hello" "again""# + "\n")
        self.assertMultipleParses([#"a001 LOGIN "hello" "you""# + "\r\n",
                                   #"a002 LOGIN "hello" "again""# + "\n"
        ])
    }

    func testTwoRegularLiteralsChunked() {
        self.feed("a001 LOGIN")
        XCTAssert(self.parses.isEmpty)
        self.feed(#" {5}"# + "\r\n")
        XCTAssertEqual(1, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("hello ")
        XCTAssertEqual(1, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("{3}\r")
        XCTAssertEqual(1, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("\n")
        XCTAssertEqual(2, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("you\r\n")
        self.assertOneParse("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\n", numberOfContinuations: 2)
    }

    func testRegularLiteralOfZeroSize() {
        self.feed("a001 LOGIN \"\" {0}\r\n\r\n")
        self.assertOneParse("a001 LOGIN \"\" {0}\r\n\r\n", numberOfContinuations: 1)
    }

    func testPlusLiteralOfZeroSize() {
        self.feed("a001 LOGIN \"\" {0+}\r\n\r\n")
        self.assertOneParse("a001 LOGIN \"\" {0+}\r\n\r\n", numberOfContinuations: 0)
    }

    func testTwoRegularLiteralOfZeroSize() {
        self.feed("a001 LOGIN {0}\r\n {0}\r\n\r\n")
        self.assertOneParse("a001 LOGIN {0}\r\n {0}\r\n\r\n", numberOfContinuations: 2)
    }

    func testTwoRegularLiteralsOneShot() {
        self.feed("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\n")
        self.assertOneParse("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\n", numberOfContinuations: 2)
    }

    func testTwoRegularLiteralsChunkedPlusExtraBits() {
        self.feed("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\nLOGIN {4}\r\nwhat")
        self.assertOneParse("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\n", numberOfContinuations: 3)
    }

    func testTwoRegularLiteralsOnePlusLiteralOneShot() {
        self.feed("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\nLOGIN {4+}\r\nwhat")
        self.assertOneParse("a001 LOGIN {5}\r\nhello {3}\r\nyou\r\n", numberOfContinuations: 2)
    }

    func testOnePlusLiteralOneRegularLiteral() {
        self.feed("a001 LOGIN {5+}\r\nhello {3}\r\nyou\r\n")
        self.assertOneParse("a001 LOGIN {5+}\r\nhello {3}\r\nyou\r\n", numberOfContinuations: 1)
    }

    func testOnePlusLiteralOneMinusLiteral() {
        self.feed("a001 LOGIN {5+}\r\nhello {3-}\r\nyou\r\n")
        self.assertOneParse("a001 LOGIN {5+}\r\nhello {3-}\r\nyou\r\n", numberOfContinuations: 0)
    }

    func testTwoRegularTildeLiterals() {
        self.feed("a001 LOGIN {~5}\r\nhello {~3}\r\nyou\r\n")
        self.assertOneParse("a001 LOGIN {~5}\r\nhello {~3}\r\nyou\r\n", numberOfContinuations: 2)
    }

    func testTwoPlusLiteralsChunked() {
        self.feed("a001 LOGIN")
        XCTAssert(self.parses.isEmpty)
        self.feed(#" {5+}"# + "\r\n")
        XCTAssertEqual(0, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("hello ")
        XCTAssertEqual(0, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("{3+}\r")
        XCTAssertEqual(0, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("\n")
        XCTAssertEqual(0, self.continuationsParsed)
        XCTAssert(self.parses.isEmpty)
        self.feed("you\r\n")
        self.assertOneParse("a001 LOGIN {5+}\r\nhello {3+}\r\nyou\r\n", numberOfContinuations: 0)
    }

    func testWeCanGoOverBufferLimitIfWeManageToMakeCompleteLine() {
        self.feed("a001 LOGIN {5+}\r\nhello {3+}\r\nyou\r\n" + String(repeating: "X", count: 100))
        self.assertOneParse("a001 LOGIN {5+}\r\nhello {3+}\r\nyou\r\n", numberOfContinuations: 0)
    }

    func testWeStartStreamingWhenWeGoOverChunked1() {
        let hundredXs = String(repeating: "X", count: 100)
        let xs799 = String(repeating: "X", count: 799)
        self.feed("a001 LOGIN {1000}\r\n" + hundredXs)
        XCTAssertEqual(2, self.parses.count)
        XCTAssertEqual(1, self.continuationsParsed)
        self.feed(hundredXs + "Y")
        XCTAssertEqual(3, self.parses.count)
        self.feed(xs799)
        XCTAssertEqual(4, self.parses.count)
        self.feed("\r")
        XCTAssertEqual(4, self.parses.count)
        self.feed("\n")
        XCTAssertEqual(5, self.parses.count)
        self.feed(#"LOGIN "a" "b""# + "\r\n")
        XCTAssertEqual(6, self.parses.count)
        self.assertMultipleParses(["a001 LOGIN {1000}\r\n",
                                   hundredXs,       // 100
                                   hundredXs + "Y", // 201
                                   xs799,
                                   "\r\n",
                                   #"LOGIN "a" "b""# + "\r\n"
                                  ], numberOfContinuations: 1)
    }

    func testWeStartStreamingWhenWeGoOverChunked2() {
        let hundredXs = String(repeating: "X", count: 100)
        let xs799 = String(repeating: "X", count: 799)
        self.feed("a001 LOGIN {1000}\r\n" + hundredXs)
        XCTAssertEqual(2, self.parses.count)
        XCTAssertEqual(1, self.continuationsParsed)
        self.feed(hundredXs + "Y")
        XCTAssertEqual(3, self.parses.count)
        self.feed(xs799)
        XCTAssertEqual(4, self.parses.count)
        self.feed("\r\n")
        XCTAssertEqual(5, self.parses.count)
        self.feed(#"LOGIN "a" "b""# + "\r\n")
        XCTAssertEqual(6, self.parses.count)
        self.assertMultipleParses(["a001 LOGIN {1000}\r\n",
                                   hundredXs,       // 100
                                   hundredXs + "Y", // 201
                                   xs799,
                                   "\r\n",
                                   #"LOGIN "a" "b""# + "\r\n"
                                  ], numberOfContinuations: 1)
    }

    func testWeStartStreamingWhenWeGoOverChunked3() {
        let hundredXs = String(repeating: "X", count: 100)
        let xs799 = String(repeating: "X", count: 799)
        self.feed("a001 LOGIN {1000}\r\n" + hundredXs)
        XCTAssertEqual(2, self.parses.count)
        XCTAssertEqual(1, self.continuationsParsed)
        self.feed(hundredXs + "Y")
        XCTAssertEqual(3, self.parses.count)
        self.feed(xs799)
        XCTAssertEqual(4, self.parses.count)
        self.feed("\r")
        XCTAssertEqual(4, self.parses.count)
        self.feed("\n" + #"LOGIN "a" "b""# + "\r\n")
        XCTAssertEqual(6, self.parses.count)
        self.assertMultipleParses(["a001 LOGIN {1000}\r\n",
                                   hundredXs,       // 100
                                   hundredXs + "Y", // 201
                                   xs799,
                                   "\r\n",
                                   #"LOGIN "a" "b""# + "\r\n"
                                  ], numberOfContinuations: 1)
    }

    func testWeStartStreamingWhenWeGoOverChunked4() {
        let hundredXs = String(repeating: "X", count: 100)
        let xs799 = String(repeating: "X", count: 799)
        self.feed("a001 LOGIN {1000}\r\n" + hundredXs)
        XCTAssertEqual(2, self.parses.count)
        XCTAssertEqual(1, self.continuationsParsed)
        self.feed(hundredXs + "Y")
        XCTAssertEqual(3, self.parses.count)
        self.feed(xs799)
        XCTAssertEqual(4, self.parses.count)
        self.feed("\r\n" + #"LOGIN "a" "b""# + "\r\n")
        XCTAssertEqual(6, self.parses.count)
        self.assertMultipleParses(["a001 LOGIN {1000}\r\n",
                                   hundredXs,       // 100
                                   hundredXs + "Y", // 201
                                   xs799,
                                   "\r\n",
                                   #"LOGIN "a" "b""# + "\r\n"
                                  ], numberOfContinuations: 1)
    }

    func testWeStartStreamingWhenWeGetEverythingOneShot() {
        let hundredXs = String(repeating: "X", count: 100)
        let xs799 = String(repeating: "X", count: 799)
        self.feed("a001 LOGIN {1000}\r\n" + hundredXs + hundredXs + "Y" + xs799 + "\r\n" + #"LOGIN "a" "b""# + "\r\n")
        self.assertMultipleParses(["a001 LOGIN {1000}\r\n",
                                   hundredXs + hundredXs + "Y" + xs799,
                                   "\r\n",
                                   #"LOGIN "a" "b""# + "\r\n"
                                  ], numberOfContinuations: 1)
    }

    func testStreamingResponse() {
        let hundredXs = String(repeating: "X", count: 100)
        self.feed("* 1 FETCH (BODY[TEXT] {101}\r\n\(hundredXs)")
        XCTAssertEqual(2, self.parses.count)
        XCTAssertEqual(1, self.continuationsParsed)
        self.feed("Y FLAGS (\\seen \\answered))\r\n")
        self.assertMultipleParses(["* 1 FETCH (BODY[TEXT] {101}\r\n",
                                   hundredXs,
                                   "Y",
                                   " FLAGS (\\seen \\answered))\r\n",
                                  ], numberOfContinuations: 1)
    }

    func testLimitWorks() {
        var justTooLong = #"a LOGIN ""#
        justTooLong.append(String(repeating: "X",
                                  count: self.parser.bufferSizeLimit - justTooLong.utf8.count + 1))
        XCTAssertThrowsError(try self.feedAllowingErrors(justTooLong)) { error in
            XCTAssertEqual(.lineTooLong, error as? NIOIMAP.ParsingError)
        }
    }

    func testObviouslyBogusCommands() {
        for badString in ["a LOGIN {}\r\n", "a LOGIN {+}\r\n", "a LOGIN {-}\r\n", "a LOGIN ~{}\r\n",
                          "}\r\n"] {
            XCTAssertThrowsError(try self.feedAllowingErrors(badString), "'\(badString)'") { error in
                XCTAssert(error is ParserError, "\(error) for \(badString) isn't right")
            }
        }
    }

    func testOkayWithNothing() {
        self.feed("")
        XCTAssertEqual(0, self.parses.count)
        XCTAssertEqual(0, self.continuationsParsed)
    }

    func testOkayWithJustNewlines() {
        for goods in ["\n", "\r\n"].enumerated() {
            self.feed(goods.element)
            XCTAssertEqual(goods.offset + 1, self.parses.count)
            XCTAssertEqual(0, self.continuationsParsed)
        }
    }


    private func assertOneParse(_ expected: String,
                                numberOfContinuations: Int? = 0,
                                file: StaticString = #file,
                                line: UInt = #line) {
        let expectedArray = [self.stringBuffer(expected)]
        let actual = self.parses
        func whyUnequal() -> String {
            guard !actual.isEmpty else {
                return "<no parses>"
            }
            return "expected: \(String(decoding: expectedArray[0].readableBytesView, as: Unicode.UTF8.self)), " +
                   "actual: \(String(decoding: actual[0].readableBytesView, as: Unicode.UTF8.self))"
        }
        XCTAssertEqual(numberOfContinuations, self.continuationsParsed, file: file, line: line)
        XCTAssertEqual(expectedArray, actual, whyUnequal(), file: file, line: line)
    }

    private func assertMultipleParses(_ expected: [String],
                                      numberOfContinuations: Int? = 0,
                                      file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(numberOfContinuations, self.continuationsParsed)
        XCTAssertEqual(expected.map(self.stringBuffer(_:)), self.parses, file: file, line: line)
    }

    private func stringBuffer(_ string: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count + 10)
        buffer.writeString("01234")
        buffer.moveReaderIndex(to: buffer.writerIndex)
        buffer.writeString(string)
        buffer.setString("56789", at: buffer.writerIndex)
        return buffer
    }
}
