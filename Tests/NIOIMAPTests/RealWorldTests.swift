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
        tag OK [REFERRAL imap://hostname/foo/bar/;UID=1234]

        """

        let inoutPairs: [(String, [ResponseOrContinuationRequest])] = [
            (
                input,
                [
                    .response(.fetch(.start(1))),
                    .response(.fetch(.simpleAttribute(.uid(54)))),
                    .response(.fetch(.simpleAttribute(.rfc822Size(40639)))),
                    .response(.fetch(.finish)),
                    .response(.fetch(.start(2))),
                    .response(.fetch(.simpleAttribute(.uid(55)))),
                    .response(.fetch(.simpleAttribute(.rfc822Size(27984)))),
                    .response(.fetch(.finish)),
                    .response(.fetch(.start(3))),
                    .response(.fetch(.simpleAttribute(.uid(56)))),
                    .response(.fetch(.simpleAttribute(.rfc822Size(34007)))),
                    .response(.fetch(.finish)),
                    .response(.tagged(.init(tag: "15.16", state: .ok(.init(code: nil, text: "Fetch completed (0.001 + 0.000 secs)."))))),
                    .response(.tagged(
                        TaggedResponse(tag: "tag",
                                       state: .ok(ResponseText(code:
                                           .referral(IMAPURL(server: IMAPServer(userAuthenticationMechanism: nil, host: "hostname", port: nil),
                                                             query: URLCommand.fetch(
                                                                 path: MessagePath(
                                                                     mailboxReference: MailboxUIDValidity(encodeMailbox: EncodedMailbox(mailbox: "foo/bar"),
                                                                                                          uidValidity: nil),
                                                                     iUID: IUID(uid: 1234),
                                                                     section: nil,
                                                                     range: nil
                                                                 ),
                                                                 authenticatedURL: nil
                                                             ))),
                                           text: ""))))),
                ]
            ),
        ]

        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> ResponseDecoder in
                    ResponseDecoder()
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<CommandStreamPart> {
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
