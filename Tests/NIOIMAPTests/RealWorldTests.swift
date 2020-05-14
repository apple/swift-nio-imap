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

final class RealWorldTests: XCTestCase {}

// MARK: Test stream simple fetch responses

extension RealWorldTests {
    func test_realWorldTest() {
        let input = """
        * 1 FETCH (UID 54 RFC822.SIZE 40639)
        * 2 FETCH (UID 55 RFC822.SIZE 27984)
        * 3 FETCH (UID 56 RFC822.SIZE 34007)
        15.16 OK Fetch completed (0.001 + 0.000 secs).

        """

        let inoutPairs: [(String, [NIOIMAPCore.Response])] = [
            (
                input,
                [
                    .fetchResponse(.start(1)),
                    .fetchResponse(.simpleAttribute(.uid(54))),
                    .fetchResponse(.simpleAttribute(.rfc822Size(40639))),
                    .fetchResponse(.finish),
                    .fetchResponse(.start(2)),
                    .fetchResponse(.simpleAttribute(.uid(55))),
                    .fetchResponse(.simpleAttribute(.rfc822Size(27984))),
                    .fetchResponse(.finish),
                    .fetchResponse(.start(3)),
                    .fetchResponse(.simpleAttribute(.uid(56))),
                    .fetchResponse(.simpleAttribute(.rfc822Size(34007))),
                    .fetchResponse(.finish),
                    .taggedResponse(.init(tag: "15.16", state: .ok(.init(code: nil, text: "Fetch completed (0.001 + 0.000 secs).")))),
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
            switch error as? ByteToMessageDecoderVerifier.VerificationError<CommandStream> {
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
