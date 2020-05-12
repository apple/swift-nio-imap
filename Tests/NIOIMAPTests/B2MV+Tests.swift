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
        let inoutPairs: [(String, [CommandStream])] = [
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

            (#"tag RENAME "foo" "bar""# + CRLF, [.command(TaggedCommand("tag", .rename(from: MailboxName("foo"), to: MailboxName("bar"), params: [])))]),
            (#"tag RENAME InBoX "inBOX""# + CRLF, [.command(TaggedCommand("tag", .rename(from: .inbox, to: .inbox, params: [])))]),
            ("tag RENAME {1}\r\n1 {1}\r\n2" + CRLF, [.command(TaggedCommand("tag", .rename(from: MailboxName("1"), to: MailboxName("2"), params: [])))]),

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
            
            // MARK: List
            
            ("tag LIST INBOX \"\"" + CRLF, [.command(.init("tag", .list(nil, .inbox, .mailbox(""), [])))]),
            ("tag LIST /Mail/ %" + CRLF, [.command(.init("tag", .list(nil, .init("/Mail/"), .mailbox("%"), [])))]),
            
            // MARK: LSUB
            
            ("tag LSUB INBOX \"\"" + CRLF, [.command(.init("tag", .lsub(.inbox, "")))]),
            
            // MARK: Status
            
            ("tag STATUS INBOX (MESSAGES)" + CRLF, [.command(.init("tag", .status(.inbox, [.messages])))]),
            ("tag STATUS INBOX (MESSAGES RECENT UIDNEXT)" + CRLF, [.command(.init("tag", .status(.inbox, [.messages, .recent, .uidnext])))]),
            
            // MARK: Append
            
//            ("tag APPEND box (\\Seen) {1}\r\na" + CRLF, [
//                .command(.init("tag", .append(to: .init("box"), firstMessageMetadata: .options(.flagList([.seen], dateTime: nil, extensions: []), data: .init(byteCount: 1))))),
//                .bytes("a"),
//            ])
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> CommandDecoder in
                    CommandDecoder(autoSendContinuations: false)
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
                    XCTFail("UNDER PRODUCTION")
                    print(command)
                    return
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    XCTFail("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                    return
                case .overProduction(let command):
                    XCTFail("OVER PRODUCTION")
                    print(command)
                    return
                default:
                    XCTFail("\(error)")
                    return
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
    func testResponse() {
        
        let inoutPairs: [(String, [Response])] = [
            
            // MARK: OK
            ("* OK Server ready" + CRLF, [.untaggedResponse(.conditionalState(.ok(.code(nil, text: "Server ready"))))]),
            ("* OK [ALERT] Server ready" + CRLF, [.untaggedResponse(.conditionalState(.ok(.code(.alert, text: "Server ready"))))]),
            ("* NO Disk full" + CRLF, [.untaggedResponse(.conditionalState(.no(.code(nil, text: "Disk full"))))]),
            ("* NO [READ-ONLY] Disk full" + CRLF, [.untaggedResponse(.conditionalState(.no(.code(.readOnly, text: "Disk full"))))]),
            ("* BAD horrible" + CRLF, [.untaggedResponse(.conditionalState(.bad(.code(nil, text: "horrible"))))]),
            ("* BAD [BADCHARSET (utf123)] horrible" + CRLF, [.untaggedResponse(.conditionalState(.bad(.code(.badCharset(["utf123"]), text: "horrible"))))]),
            
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
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
                    XCTFail("UNDER PRODUCTION")
                    print(command)
                    return
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    XCTFail("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                    return
                case .overProduction(let command):
                    XCTFail("OVER PRODUCTION")
                    print(command)
                    return
                default:
                    XCTFail("\(error)")
                    return
                }
            case .none:
                ()
            }
            XCTFail("unhandled error: \(error)")
        }
    }
        
}
