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
@testable import NIOIMAP
import NIOIMAPCore
import NIOTestUtils

final class B2MV_Tests: XCTestCase {}

// MARK: - Command

extension B2MV_Tests {
    func testCommand() {
        let inoutPairs: [(String, [CommandStreamPart])] = [
            // MARK: Capability

            ("tag CAPABILITY", [.tagged(.init(tag: "tag", command: .capability))]),

            // MARK: Noop

            ("tag NOOP", [.tagged(.init(tag: "tag", command: .noop))]),

            // MARK: Logout

            ("tag LOGOUT", [.tagged(.init(tag: "tag", command: .logout))]),

            // MARK: StartTLS

            ("tag STARTTLS", [.tagged(.init(tag: "tag", command: .startTLS))]),

            // MARK: Authenticate

            // this tests causes nothing but trouble
            // ("tag AUTHENTICATE PLAIN", [.command(.init("tag", .authenticate("PLAIN", nil, [])))]),

            // MARK: Login

            (#"tag LOGIN "foo" "bar""#, [.tagged(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),
            ("tag LOGIN \"\" {0+}\n", [.tagged(.init(tag: "tag", command: .login(username: "", password: "")))]),
            (#"tag LOGIN "foo" "bar""#, [.tagged(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),
            (#"tag LOGIN foo bar"#, [.tagged(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),

            // MARK: Select

            ("tag SELECT box1", [.tagged(.init(tag: "tag", command: .select(.init("box1"), [])))]),
            ("tag SELECT \"box2\"", [.tagged(.init(tag: "tag", command: .select(.init("box2"), [])))]),
            ("tag SELECT {4+}\nbox3", [.tagged(.init(tag: "tag", command: .select(.init("box3"), [])))]),
            ("tag SELECT box4 (k1 1 k2 2)", [.tagged(.init(tag: "tag", command: .select(.init("box4"), [.basic(.init(key: "k1", value: .sequence(.set([1])))), .basic(.init(key: "k2", value: .sequence(.set([2]))))])))]),

            // MARK: Examine

            ("tag EXAMINE box1", [.tagged(.init(tag: "tag", command: .examine(.init("box1"), [])))]),
            ("tag EXAMINE \"box2\"", [.tagged(.init(tag: "tag", command: .examine(.init("box2"), [])))]),
            ("tag EXAMINE {4+}\nbox3", [.tagged(.init(tag: "tag", command: .examine(.init("box3"), [])))]),
            ("tag EXAMINE box4 (k3 1 k4 2)", [.tagged(.init(tag: "tag", command: .examine(.init("box4"), [.basic(.init(key: "k3", value: .sequence(.set([1])))), .basic(.init(key: "k4", value: .sequence(.set([2]))))])))]),
            ("tag EXAMINE box4 (QRESYNC (67890007 20050715194045000 41,43:211,214:541))", [.tagged(.init(tag: "tag", command: .examine(.init("box4"), [.qresync(QResyncParameter(uidValidity: 67890007, modificationSequenceValue: 20050715194045000, knownUIDs: [41, 43 ... 211, 214 ... 541], sequenceMatchData: nil))])))]),
            ("tag EXAMINE box4 (CONDSTORE)", [.tagged(.init(tag: "tag", command: .examine(.init("box4"), [.condStore])))]),

            // MARK: Create

            ("tag CREATE newBox1", [.tagged(.init(tag: "tag", command: .create(.init("newBox1"), [])))]),
            ("tag CREATE \"newBox2\"", [.tagged(.init(tag: "tag", command: .create(.init("newBox2"), [])))]),
            ("tag CREATE {7+}\nnewBox3", [.tagged(.init(tag: "tag", command: .create(.init("newBox3"), [])))]),
            ("tag CREATE newBox4 (k5 5 k6 6)", [.tagged(.init(tag: "tag", command: .create(.init("newBox4"), [.labelled(.init(key: "k5", value: .sequence(.set([5])))), .labelled(.init(key: "k6", value: .sequence(.set([6]))))])))]),

            // MARK: Delete

            ("tag DELETE box1", [.tagged(.init(tag: "tag", command: .delete(.init("box1"))))]),
            ("tag DELETE \"box1\"", [.tagged(.init(tag: "tag", command: .delete(.init("box1"))))]),
            ("tag DELETE {4+}\nbox1", [.tagged(.init(tag: "tag", command: .delete(.init("box1"))))]),

            // MARK: Rename

            (#"tag RENAME "foo" "bar""#, [.tagged(TaggedCommand(tag: "tag", command: .rename(from: MailboxName("foo"), to: MailboxName("bar"), parameters: [:])))]),
            (#"tag RENAME InBoX "inBOX""#, [.tagged(TaggedCommand(tag: "tag", command: .rename(from: .inbox, to: .inbox, parameters: [:])))]),
            ("tag RENAME {1+}\n1 {1+}\n2", [.tagged(TaggedCommand(tag: "tag", command: .rename(from: MailboxName("1"), to: MailboxName("2"), parameters: [:])))]),

            // MARK: Subscribe

            ("tag SUBSCRIBE inbox", [.tagged(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE INBOX", [.tagged(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE iNbOx", [.tagged(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE \"INBOX\"", [.tagged(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE {5+}\nINBOX", [.tagged(.init(tag: "tag", command: .subscribe(.inbox)))]),

            // MARK: Unsubscribe

            ("tag UNSUBSCRIBE inbox", [.tagged(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE INBOX", [.tagged(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE iNbOx", [.tagged(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE \"INBOX\"", [.tagged(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE {5+}\nINBOX", [.tagged(.init(tag: "tag", command: .unsubscribe(.inbox)))]),

            // MARK: Check

            ("tag CHECK", [.tagged(.init(tag: "tag", command: .check))]),

            // MARK: List

            ("tag LIST INBOX \"\"", [.tagged(.init(tag: "tag", command: .list(nil, reference: .inbox, .mailbox(""))))]),
            ("tag LIST /Mail/ %", [.tagged(.init(tag: "tag", command: .list(nil, reference: .init("/Mail/"), .mailbox("%"))))]),

            // MARK: LSUB

            ("tag LSUB INBOX \"\"", [.tagged(.init(tag: "tag", command: .lsub(reference: .inbox, pattern: "")))]),

            // MARK: Status

            ("tag STATUS INBOX (MESSAGES)", [.tagged(.init(tag: "tag", command: .status(.inbox, [.messageCount])))]),
            ("tag STATUS INBOX (MESSAGES RECENT UIDNEXT)", [.tagged(.init(tag: "tag", command: .status(.inbox, [.messageCount, .recentCount, .uidNext])))]),

            // MARK: Append

            ("tag APPEND box (\\Seen) {1+}\na", [
                .append(.start(tag: "tag", appendingTo: .init("box"))),
                .append(.beginMessage(message: .init(options: .init(flagList: [.seen], extensions: [:]), data: .init(byteCount: 1)))),
                .append(.messageBytes("a")),
                .append(.endMessage),
                .append(.finish),
            ]),
        ]

        let input = inoutPairs.map { ($0.0 + "\n", $0.1.map { SynchronizedCommand($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: input,
                decoderFactory: { () -> CommandDecoder in
                    CommandDecoder()
                }
            )
        } catch let error as ByteToMessageDecoderVerifier.VerificationError<SynchronizedCommand> {
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

            ("* OK Server ready", [.untagged(.conditionalState(.ok(.init(code: nil, text: "Server ready"))))]),
            ("* OK [ALERT] Server ready", [.untagged(.conditionalState(.ok(.init(code: .alert, text: "Server ready"))))]),
            ("* NO Disk full", [.untagged(.conditionalState(.no(.init(code: nil, text: "Disk full"))))]),
            ("* NO [READ-ONLY] Disk full", [.untagged(.conditionalState(.no(.init(code: .readOnly, text: "Disk full"))))]),
            ("* BAD horrible", [.untagged(.conditionalState(.bad(.init(code: nil, text: "horrible"))))]),
            ("* BAD [BADCHARSET (utf123)] horrible", [.untagged(.conditionalState(.bad(.init(code: .badCharset(["utf123"]), text: "horrible"))))]),

            // MARK: Bye

            ("* BYE logging off", [.untagged(.conditionalState(.bye(.init(code: nil, text: "logging off"))))]),
            ("* BYE [ALERT] logging off", [.untagged(.conditionalState(.bye(.init(code: .alert, text: "logging off"))))]),

            // MARK: Capability

            ("* CAPABILITY IMAP4rev1 CHILDREN CONDSTORE", [.untagged(.capabilityData([.imap4rev1, .children, .condStore]))]),
            // With trailing space:
            ("* CAPABILITY IMAP4rev1 CHILDREN CONDSTORE ", [.untagged(.capabilityData([.imap4rev1, .children, .condStore]))]),

            // MARK: LIST

            ("* LIST (\\noselect) \"/\" ~/Mail/foo", [.untagged(.mailboxData(.list(.init(attributes: [.noSelect], path: try! .init(name: .init("~/Mail/foo"), pathSeparator: "/"), extensions: [:]))))]),

            // MARK: LSUB

            ("* LSUB (\\noselect) \"/\" ~/Mail/foo", [.untagged(.mailboxData(.lsub(.init(attributes: [.noSelect], path: try! .init(name: .init("~/Mail/foo"), pathSeparator: "/"), extensions: [:]))))]),

            // MARK: Status

            ("* STATUS INBOX (MESSAGES 231 UIDNEXT 44292)", [.untagged(.mailboxData(.status(.inbox, .init(messageCount: 231, nextUID: 44292))))]),

            // MARK: Flags

            ("* FLAGS (\\Answered \\Seen)", [.untagged(.mailboxData(.flags([.answered, .seen])))]),

            // MARK: Exists

            ("* 23 EXISTS", [.untagged(.mailboxData(.exists(23)))]),

            // MARK: Recent

            ("* 5 RECENT", [.untagged(.mailboxData(.recent(5)))]),

            // MARK: Expunge

            ("* 20 EXPUNGE", [.untagged(.messageData(.expunge(20)))]),

            // MARK: Fetch

            (
                "* 1 FETCH (UID 999)",
                [.fetch(.start(1)), .fetch(.simpleAttribute(.uid(999))), .fetch(.finish)]
            ),
            (
                "* 2 FETCH (UID 111 FLAGS (\\Seen \\Deleted \\Answered))",
                [
                    .fetch(.start(2)),
                    .fetch(.simpleAttribute(.uid(111))),
                    .fetch(.simpleAttribute(.flags([.seen, .deleted, .answered]))),
                    .fetch(.finish),
                ]
            ),

            // MARK: Tagged

            ("tag OK Complete", [.tagged(.init(tag: "tag", state: .ok(.init(code: nil, text: "Complete"))))]),
            ("tag NO [ALERT] Complete", [.tagged(.init(tag: "tag", state: .no(.init(code: .alert, text: "Complete"))))]),
            ("tag BAD [PARSE] Complete", [.tagged(.init(tag: "tag", state: .bad(.init(code: .parse, text: "Complete"))))]),
        ]

        let inputs = inoutPairs.map { ($0.0 + "\n", $0.1.map { ResponseOrContinuationRequest.response($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inputs,
                decoderFactory: { () -> ResponseDecoder in
                    ResponseDecoder()
                }
            )
        } catch let error as ByteToMessageDecoderVerifier.VerificationError<CommandStreamPart> {
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
