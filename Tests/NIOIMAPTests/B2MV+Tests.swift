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

import Foundation
import XCTest

import NIO
import NIOIMAP
import NIOIMAPCore
import NIOTestUtils

final class B2MV_Tests: XCTestCase {}

// MARK: - Command

extension B2MV_Tests {
    func testCommand() {
        let inoutPairs: [(String, [NIOIMAP.CommandStream])] = [
            // MARK: Capability

            ("tag CAPABILITY" + CRLF, [.command(.init("tag", .capability))]),

            // MARK: Noop

            ("tag NOOP" + CRLF, [.command(.init("tag", .noop))]),

            // MARK: Logout

            ("tag LOGOUT" + CRLF, [.command(.init("tag", .logout))]),

            // MARK: StartTLS

            ("tag STARTTLS" + CRLF, [.command(.init("tag", .starttls))]),

            // MARK: Authenticate

            // this tests causes nothing but trouble
            // ("tag AUTHENTICATE PLAIN" + CRLF, [.command(.init("tag", .authenticate("PLAIN", nil, [])))]),

            // MARK: Login

            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            ("tag LOGIN \"\" {0}\r\n" + CRLF, [.command(.init("tag", .login("", "")))]),
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            (#"tag LOGIN foo bar"# + CRLF, [.command(.init("tag", .login("foo", "bar")))]),

            // MARK: Select

            ("tag SELECT box1" + CRLF, [.command(.init("tag", .select(.init("box1"), [])))]),
            ("tag SELECT \"box2\"" + CRLF, [.command(.init("tag", .select(.init("box2"), [])))]),
            ("tag SELECT {4}\r\nbox3" + CRLF, [.command(.init("tag", .select(.init("box3"), [])))]),
            ("tag SELECT box4 (k1 1 k2 2)" + CRLF, [.command(.init("tag", .select(.init("box4"), [.name("k1", value: .simple(.sequence([1]))), .name("k2", value: .simple(.sequence([2])))])))]),

            // MARK: Examine

            ("tag EXAMINE box1" + CRLF, [.command(.init("tag", .examine(.init("box1"), [])))]),
            ("tag EXAMINE \"box2\"" + CRLF, [.command(.init("tag", .examine(.init("box2"), [])))]),
            ("tag EXAMINE {4}\r\nbox3" + CRLF, [.command(.init("tag", .examine(.init("box3"), [])))]),
            ("tag EXAMINE box4 (k3 1 k4 2)" + CRLF, [.command(.init("tag", .examine(.init("box4"), [.name("k3", value: .simple(.sequence([1]))), .name("k4", value: .simple(.sequence([2])))])))]),

            // MARK: Create

            ("tag CREATE newBox1" + CRLF, [.command(.init("tag", .create(.init("newBox1"), [])))]),
            ("tag CREATE \"newBox2\"" + CRLF, [.command(.init("tag", .create(.init("newBox2"), [])))]),
            ("tag CREATE {7}\r\nnewBox3" + CRLF, [.command(.init("tag", .create(.init("newBox3"), [])))]),
            ("tag CREATE newBox4 (k5 5 k6 6)" + CRLF, [.command(.init("tag", .create(.init("newBox4"), [.name("k5", value: .simple(.sequence([5]))), .name("k6", value: .simple(.sequence([6])))])))]),

            // MARK: Delete

            ("tag DELETE box1" + CRLF, [.command(.init("tag", .delete(.init("box1"))))]),
            ("tag DELETE \"box1\"" + CRLF, [.command(.init("tag", .delete(.init("box1"))))]),
            ("tag DELETE {4}\r\nbox1" + CRLF, [.command(.init("tag", .delete(.init("box1"))))]),

            // MARK: Rename

            (#"tag RENAME "foo" "bar""# + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: NIOIMAP.MailboxName("foo"), to: NIOIMAP.MailboxName("bar"), params: [])))]),
            (#"tag RENAME InBoX "inBOX""# + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: .inbox, to: .inbox, params: [])))]),
            ("tag RENAME {1}\r\n1 {1}\r\n2" + CRLF, [.command(NIOIMAP.TaggedCommand("tag", .rename(from: NIOIMAP.MailboxName("1"), to: NIOIMAP.MailboxName("2"), params: [])))]),

            // MARK: Subscribe

            ("tag SUBSCRIBE inbox" + CRLF, [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE INBOX" + CRLF, [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE iNbOx" + CRLF, [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE \"INBOX\"" + CRLF, [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE {5}\r\nINBOX" + CRLF, [.command(.init("tag", .subscribe(.inbox)))]),

            // MARK: Unsubscribe

            ("tag UNSUBSCRIBE inbox" + CRLF, [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE INBOX" + CRLF, [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE iNbOx" + CRLF, [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE \"INBOX\"" + CRLF, [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE {5}\r\nINBOX" + CRLF, [.command(.init("tag", .unsubscribe(.inbox)))]),

            // MARK: Check

            ("tag CHECK" + CRLF, [.command(.init("tag", .check))]),
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> NIOIMAP.CommandDecoder in
                    NIOIMAP.CommandDecoder(autoSendContinuations: false)
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

// MARK: - Response

extension B2MV_Tests {
    func testResponse() {}
}
