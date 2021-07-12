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
@testable import NIOIMAP
@testable import NIOIMAPCore
import NIOTestUtils
import XCTest

class ResponseDecoder_Tests: XCTestCase {}

extension ResponseDecoder_Tests {
    func testNormalUsage() throws {
        let inoutPairs: [(String, [Response])] = [
            (
                "1 OK Login\r\n",
                [
                    .tagged(.init(tag: "1", state: .ok(.init(code: nil, text: "Login")))),
                ]
            ),
            (
                "* NO [ALERT] ohno\r\n",
                [
                    .untagged(.conditionalState(.no(.init(code: .alert, text: "ohno")))),
                ]
            ),
            (
                "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {1}\r\nX)\r\n2 OK Fetch completed.\r\n",
                [
                    .fetch(.start(2)),
                    .fetch(.simpleAttribute(.flags([.deleted]))),
                    .fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 1)),
                    .fetch(.streamingBytes("X")),
                    .fetch(.streamingEnd),
                    .fetch(.finish),
                    .tagged(.init(tag: "2", state: .ok(.init(code: nil, text: "Fetch completed.")))),
                ]
            ),
            (
                "* 2 FETCH (FLAGS (\\deleted) BODY[1.2.TEXT]<4> {1}\r\nX)\r\n2 OK Fetch completed.\r\n",
                [
                    .fetch(.start(2)),
                    .fetch(.simpleAttribute(.flags([.deleted]))),
                    .fetch(.streamingBegin(kind: .body(section: .init(part: [1, 2], kind: .text), offset: 4), byteCount: 1)),
                    .fetch(.streamingBytes("X")),
                    .fetch(.streamingEnd),
                    .fetch(.finish),
                    .tagged(.init(tag: "2", state: .ok(.init(code: nil, text: "Fetch completed.")))),
                ]
            ),
        ]

        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs.map { ($0, $1.map { .response($0) }) },
                decoderFactory: { () -> ResponseDecoder in
                    ResponseDecoder()
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<Response> {
            case .some(let error):
                for input in error.inputs {
                    print(" input: \(String(decoding: input.readableBytesView, as: Unicode.UTF8.self))")
                }
                switch error.errorCode {
                case .underProduction(let command):
                    print("UNDER PRODUCTION")
                    print(command)
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    print("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                default:
                    print(error)
                }
            case .none:
                ()
            }
            XCTFail("unhandled error: \(error)")
        }
    }
}
