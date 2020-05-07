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

class ResponseDecoder_Tests: XCTest {}

extension ResponseDecoder_Tests {
    func testNormalUsage() throws {
        let inoutPairs: [(String, [Response])] = [
            (
                "1 OK Login\r\n",
                [
                    .taggedResponse(.init(tag: "1", state: .ok(.init(code: nil, text: "Login")))),
                ]
            ),
            (
                "* NO [ALERT] ohno\r\n",
                [
                    .untaggedResponse(.conditionalState(.no(.init(code: .alert, text: "ohno")))),
                ]
            ),
            (
                "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {1}\r\nX)\r\n2 OK Fetch completed.\r\n",
                [
                    .fetchResponse(.start(2)),
                    .fetchResponse(.simpleAttribute(.flags([.deleted]))),
                    .fetchResponse(.streamingBegin(type: .body(partial: nil), byteCount: 1)),
                    .fetchResponse(.streamingBytes("X")),
                    .fetchResponse(.streamingEnd),
                    .fetchResponse(.finish),
                    .taggedResponse(.init(tag: "2", state: .ok(.init(code: nil, text: "Fetch completed.")))),
                ]
            ),
        ]

        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> ResponseDecoder in
                    var decoder = ResponseDecoder()
                    decoder.parser.mode = .response
                    return decoder
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
