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
        
        let inoutPairs: [(String, [NIOIMAP.ServerResponse])] = [
            (
                "+ OK\r\n+ OK\r\n1 OK Login\r\n",
                [
                    .response(.init(parts: [
                        .continueRequest(.responseText(.code(nil, text: "OK"))),
                        .continueRequest(.responseText(.code(nil, text: "OK")))
                    ], done: .tagged(.init(tag: "1", state: .ok(.code(nil, text: "Login"))))))
                ]
            )
        ]
        
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: {
                    NIOIMAP.ResponseDecoder()
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<NIOIMAP.CommandStream> {
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
