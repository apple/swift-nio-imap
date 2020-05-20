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

            ("tag CAPABILITY", [.command(.init("tag", .capability))]),

            // MARK: Noop

            ("tag NOOP", [.command(.init("tag", .noop))]),

            // MARK: Logout

            ("tag LOGOUT", [.command(.init("tag", .logout))]),

            // MARK: StartTLS

            ("tag STARTTLS", [.command(.init("tag", .starttls))]),

            // MARK: Authenticate

            // this tests causes nothing but trouble
            // ("tag AUTHENTICATE PLAIN", [.command(.init("tag", .authenticate("PLAIN", nil, [])))]),

            // MARK: Login

            (#"tag LOGIN "foo" "bar""#, [.command(.init("tag", .login(username: "foo", password: "bar")))]),
            ("tag LOGIN \"\" {0+}\r\n", [.command(.init("tag", .login(username: "", password: "")))]),
            (#"tag LOGIN "foo" "bar""#, [.command(.init("tag", .login(username: "foo", password: "bar")))]),
            (#"tag LOGIN foo bar"#, [.command(.init("tag", .login(username: "foo", password: "bar")))]),

            // MARK: Select

            ("tag SELECT box1", [.command(.init("tag", .select(.init("box1"), [])))]),
            ("tag SELECT \"box2\"", [.command(.init("tag", .select(.init("box2"), [])))]),
            ("tag SELECT {4+}\r\nbox3", [.command(.init("tag", .select(.init("box3"), [])))]),
            ("tag SELECT box4 (k1 1 k2 2)", [.command(.init("tag", .select(.init("box4"), [.init(name: "k1", value: .simple(.sequence([1]))), .init(name: "k2", value: .simple(.sequence([2])))])))]),

            // MARK: Examine

            ("tag EXAMINE box1", [.command(.init("tag", .examine(.init("box1"), [])))]),
            ("tag EXAMINE \"box2\"", [.command(.init("tag", .examine(.init("box2"), [])))]),
            ("tag EXAMINE {4+}\r\nbox3", [.command(.init("tag", .examine(.init("box3"), [])))]),
            ("tag EXAMINE box4 (k3 1 k4 2)", [.command(.init("tag", .examine(.init("box4"), [.init(name: "k3", value: .simple(.sequence([1]))), .init(name: "k4", value: .simple(.sequence([2])))])))]),

            // MARK: Create

            ("tag CREATE newBox1", [.command(.init("tag", .create(.init("newBox1"), [])))]),
            ("tag CREATE \"newBox2\"", [.command(.init("tag", .create(.init("newBox2"), [])))]),
            ("tag CREATE {7+}\r\nnewBox3", [.command(.init("tag", .create(.init("newBox3"), [])))]),
            ("tag CREATE newBox4 (k5 5 k6 6)", [.command(.init("tag", .create(.init("newBox4"), [.init(name: "k5", value: .simple(.sequence([5]))), .init(name: "k6", value: .simple(.sequence([6])))])))]),

            // MARK: Delete

            ("tag DELETE box1", [.command(.init("tag", .delete(.init("box1"))))]),
            ("tag DELETE \"box1\"", [.command(.init("tag", .delete(.init("box1"))))]),
            ("tag DELETE {4+}\r\nbox1", [.command(.init("tag", .delete(.init("box1"))))]),

            // MARK: Rename

            (#"tag RENAME "foo" "bar""#, [.command(TaggedCommand("tag", .rename(from: MailboxName("foo"), to: MailboxName("bar"), params: [])))]),
            (#"tag RENAME InBoX "inBOX""#, [.command(TaggedCommand("tag", .rename(from: .inbox, to: .inbox, params: [])))]),
            ("tag RENAME {1+}\r\n1 {1+}\r\n2", [.command(TaggedCommand("tag", .rename(from: MailboxName("1"), to: MailboxName("2"), params: [])))]),

            // MARK: Subscribe

            ("tag SUBSCRIBE inbox", [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE INBOX", [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE iNbOx", [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE \"INBOX\"", [.command(.init("tag", .subscribe(.inbox)))]),
            ("tag SUBSCRIBE {5+}\r\nINBOX", [.command(.init("tag", .subscribe(.inbox)))]),

            // MARK: Unsubscribe

            ("tag UNSUBSCRIBE inbox", [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE INBOX", [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE iNbOx", [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE \"INBOX\"", [.command(.init("tag", .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE {5+}\r\nINBOX", [.command(.init("tag", .unsubscribe(.inbox)))]),

            // MARK: Check

            ("tag CHECK", [.command(.init("tag", .check))]),

            // MARK: List

            ("tag LIST INBOX \"\"", [.command(.init("tag", .list(nil, .inbox, .mailbox(""), [])))]),
            ("tag LIST /Mail/ %", [.command(.init("tag", .list(nil, .init("/Mail/"), .mailbox("%"), [])))]),

            // MARK: LSUB

            ("tag LSUB INBOX \"\"", [.command(.init("tag", .lsub(.inbox, "")))]),

            // MARK: Status

            ("tag STATUS INBOX (MESSAGES)", [.command(.init("tag", .status(.inbox, [.messages])))]),
            ("tag STATUS INBOX (MESSAGES RECENT UIDNEXT)", [.command(.init("tag", .status(.inbox, [.messages, .recent, .uidnext])))]),

            // MARK: Append

            ("tag APPEND box (\\Seen) {1+}\r\na", [
                .command(.init("tag", .append(to: .init("box"), firstMessageMetadata: .init(options: .init(flagList: [.seen], extensions: []), data: .init(byteCount: 1, synchronizing: false))))),
                .bytes("a")
            ])
        ]

        let input = inoutPairs.map { ($0.0 + CRLF, $0.1.map { CommandDecoder.PartialCommandStream($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: input,
                decoderFactory: { () -> CommandDecoder in
                    CommandDecoder()
                }
            )
        } catch let error as ByteToMessageDecoderVerifier.VerificationError<CommandDecoder.PartialCommandStream> {
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
        } catch {
            XCTFail("unhandled error: \(error)")
        }
    }
}

// MARK: - Response

extension B2MV_Tests {
    func testResponse() {
        let inoutPairs: [(String, [Response])] = [
            // MARK: State responses

            ("* OK Server ready", [.untaggedResponse(.conditionalState(.ok(.init(code: nil, text: "Server ready"))))]),
            ("* OK [ALERT] Server ready", [.untaggedResponse(.conditionalState(.ok(.init(code: .alert, text: "Server ready"))))]),
            ("* NO Disk full", [.untaggedResponse(.conditionalState(.no(.init(code: nil, text: "Disk full"))))]),
            ("* NO [READ-ONLY] Disk full", [.untaggedResponse(.conditionalState(.no(.init(code: .readOnly, text: "Disk full"))))]),
            ("* BAD horrible", [.untaggedResponse(.conditionalState(.bad(.init(code: nil, text: "horrible"))))]),
            ("* BAD [BADCHARSET (utf123)] horrible", [.untaggedResponse(.conditionalState(.bad(.init(code: .badCharset(["utf123"]), text: "horrible"))))]),

            // MARK: Bye

            ("* BYE logging off", [.untaggedResponse(.conditionalBye(.init(code: nil, text: "logging off")))]),
            ("* BYE [ALERT] logging off", [.untaggedResponse(.conditionalBye(.init(code: .alert, text: "logging off")))]),

            // MARK: Capability

            ("* CAPABILITY IMAP4rev1 CHILDREN CONDSTORE", [.untaggedResponse(.capabilityData([.imap4rev1, .children, .condStore]))]),

            // MARK: LIST

            ("* LIST (\\NoSelect) \"/\" ~/Mail/foo", [.untaggedResponse(.mailboxData(.list(.init(flags: .init(oFlags: [], sFlag: .noSelect), char: "/", mailbox: .init("~/Mail/foo"), listExtended: []))))]),

            // MARK: LSUB

            ("* LSUB (\\NoSelect) \"/\" ~/Mail/foo", [.untaggedResponse(.mailboxData(.lsub(.init(flags: .init(oFlags: [], sFlag: .noSelect), char: "/", mailbox: .init("~/Mail/foo"), listExtended: []))))]),

            // MARK: Status

            ("* STATUS INBOX (MESSAGES 231 UIDNEXT 44292)", [.untaggedResponse(.mailboxData(.status(.inbox, [.messages(231), .uidNext(44292)])))]),

            // MARK: Flags

            ("* FLAGS (\\Answered \\Seen)", [.untaggedResponse(.mailboxData(.flags([.answered, .seen])))]),

            // MARK: Exists

            ("* 23 EXISTS", [.untaggedResponse(.mailboxData(.exists(23)))]),

            // MARK: Recent

            ("* 5 RECENT", [.untaggedResponse(.mailboxData(.recent(5)))]),

            // MARK: Expunge

            ("* 20 EXPUNGE", [.untaggedResponse(.messageData(.expunge(20)))]),

            // MARK: Fetch

            (
                "* 1 FETCH (UID 999)",
                [.fetchResponse(.start(1)), .fetchResponse(.simpleAttribute(.uid(999))), .fetchResponse(.finish)]
            ),
            (
                "* 2 FETCH (UID 111 FLAGS (\\Seen \\Deleted \\Answered))",
                [
                    .fetchResponse(.start(2)),
                    .fetchResponse(.simpleAttribute(.uid(111))),
                    .fetchResponse(.simpleAttribute(.flags([.seen, .deleted, .answered]))),
                    .fetchResponse(.finish),
                ]
            ),

            // MARK: Tagged

            ("tag OK Complete", [.taggedResponse(.init(tag: "tag", state: .ok(.init(code: nil, text: "Complete"))))]),
            ("tag NO [ALERT] Complete", [.taggedResponse(.init(tag: "tag", state: .no(.init(code: .alert, text: "Complete"))))]),
            ("tag BAD [PARSE] Complete", [.taggedResponse(.init(tag: "tag", state: .bad(.init(code: .parse, text: "Complete"))))]),
        ]

        let inputs = inoutPairs.map { ($0.0 + CRLF, $0.1.map { ResponseOrContinueRequest.response($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inputs,
                decoderFactory: { () -> ResponseDecoder in
                    ResponseDecoder(expectGreeting: false)
                }
            )
        } catch let error as ByteToMessageDecoderVerifier.VerificationError<CommandStream> {
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
        } catch {
            XCTFail("unhandled error: \(error)")
        }
    }
}
