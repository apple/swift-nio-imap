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
import NIOTestUtils
@testable import NIOIMAP

class ResponseDecoder_Tests: EncodeTestClass {

}

extension ResponseDecoder_Tests {
    
    func testNormalUsage() throws {
        
        let inoutPairs: [(String, [NIOIMAP.ResponseStream])] = [
            (
                "1 OK Login\r\n",
                [
                    .responseEnd(.tagged(.tag("1", state: .ok(.code(nil, text: "Login")))))
                ]
            ),
            (
                "* NO [ALERT] ohno\r\n",
                [
                    .responseBegin(.conditionalState(.no(.code(.alert, text: "ohno"))))
                ]
            ),
            (
                "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {1}\r\nX)\r\n2 OK Fetch completed.\r\n",
                [
                    .responseBegin(.messageData(.fetch(2))),
                    .attributesStart,
                    .simpleAttribute(.dynamic([.deleted])),
                    .streamingAttributeBegin(.bodySectionText(nil, 1)),
                    .streamingAttributeBytes(Array("X".utf8)),
                    .streamingAttributeEnd,
                    .attributesFinish,
                    .responseEnd(.tagged(.tag("2", state: .ok(.code(nil, text: "Fetch completed.")))))
                ]
            )
        ]
        
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> NIOIMAP.ResponseDecoder in
                    var decoder = NIOIMAP.ResponseDecoder()
                    decoder.parser.mode = .response
                    return decoder
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<NIOIMAP.ResponseStream> {
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
