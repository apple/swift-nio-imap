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
        let inoutPairs: [(String, [CommandStream])] = [
            // MARK: Capability

            ("tag CAPABILITY", [.command(.init(tag: "tag", command: .capability))]),

            // MARK: Noop

            ("tag NOOP", [.command(.init(tag: "tag", command: .noop))]),

            // MARK: Logout

            ("tag LOGOUT", [.command(.init(tag: "tag", command: .logout))]),

            // MARK: StartTLS

            ("tag STARTTLS", [.command(.init(tag: "tag", command: .starttls))]),

            // MARK: Authenticate

            // this tests causes nothing but trouble
            // ("tag AUTHENTICATE PLAIN", [.command(.init("tag", .authenticate("PLAIN", nil, [])))]),

            // MARK: Login

            (#"tag LOGIN "foo" "bar""#, [.command(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),
            ("tag LOGIN \"\" {0+}\r\n", [.command(.init(tag: "tag", command: .login(username: "", password: "")))]),
            (#"tag LOGIN "foo" "bar""#, [.command(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),
            (#"tag LOGIN foo bar"#, [.command(.init(tag: "tag", command: .login(username: "foo", password: "bar")))]),

            // MARK: Select

            ("tag SELECT box1", [.command(.init(tag: "tag", command: .select(.init("box1"), [])))]),
            ("tag SELECT \"box2\"", [.command(.init(tag: "tag", command: .select(.init("box2"), [])))]),
            ("tag SELECT {4+}\r\nbox3", [.command(.init(tag: "tag", command: .select(.init("box3"), [])))]),
            ("tag SELECT box4 (k1 1 k2 2)", [.command(.init(tag: "tag", command: .select(.init("box4"), [.basic(.init(key: "k1", value: .sequence([1]))), .basic(.init(key: "k2", value: .sequence([2])))])))]),

            // MARK: Examine

            ("tag EXAMINE box1", [.command(.init(tag: "tag", command: .examine(.init("box1"), [:])))]),
            ("tag EXAMINE \"box2\"", [.command(.init(tag: "tag", command: .examine(.init("box2"), [:])))]),
            ("tag EXAMINE {4+}\r\nbox3", [.command(.init(tag: "tag", command: .examine(.init("box3"), [:])))]),
            ("tag EXAMINE box4 (k3 1 k4 2)", [.command(.init(tag: "tag", command: .examine(.init("box4"), ["k3": .sequence([1]), "k4": .sequence([2])])))]),

            // MARK: Create

            ("tag CREATE newBox1", [.command(.init(tag: "tag", command: .create(.init("newBox1"), [])))]),
            ("tag CREATE \"newBox2\"", [.command(.init(tag: "tag", command: .create(.init("newBox2"), [])))]),
            ("tag CREATE {7+}\r\nnewBox3", [.command(.init(tag: "tag", command: .create(.init("newBox3"), [])))]),
            ("tag CREATE newBox4 (k5 5 k6 6)", [.command(.init(tag: "tag", command: .create(.init("newBox4"), [.labelled(.init(key: "k5", value: .sequence([5]))), .labelled(.init(key: "k6", value: .sequence([6])))])))]),

            // MARK: Delete

            ("tag DELETE box1", [.command(.init(tag: "tag", command: .delete(.init("box1"))))]),
            ("tag DELETE \"box1\"", [.command(.init(tag: "tag", command: .delete(.init("box1"))))]),
            ("tag DELETE {4+}\r\nbox1", [.command(.init(tag: "tag", command: .delete(.init("box1"))))]),

            // MARK: Rename

            (#"tag RENAME "foo" "bar""#, [.command(TaggedCommand(tag: "tag", command: .rename(from: MailboxName("foo"), to: MailboxName("bar"), params: [:])))]),
            (#"tag RENAME InBoX "inBOX""#, [.command(TaggedCommand(tag: "tag", command: .rename(from: .inbox, to: .inbox, params: [:])))]),
            ("tag RENAME {1+}\r\n1 {1+}\r\n2", [.command(TaggedCommand(tag: "tag", command: .rename(from: MailboxName("1"), to: MailboxName("2"), params: [:])))]),

            // MARK: Subscribe

            ("tag SUBSCRIBE inbox", [.command(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE INBOX", [.command(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE iNbOx", [.command(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE \"INBOX\"", [.command(.init(tag: "tag", command: .subscribe(.inbox)))]),
            ("tag SUBSCRIBE {5+}\r\nINBOX", [.command(.init(tag: "tag", command: .subscribe(.inbox)))]),

            // MARK: Unsubscribe

            ("tag UNSUBSCRIBE inbox", [.command(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE INBOX", [.command(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE iNbOx", [.command(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE \"INBOX\"", [.command(.init(tag: "tag", command: .unsubscribe(.inbox)))]),
            ("tag UNSUBSCRIBE {5+}\r\nINBOX", [.command(.init(tag: "tag", command: .unsubscribe(.inbox)))]),

            // MARK: Check

            ("tag CHECK", [.command(.init(tag: "tag", command: .check))]),

            // MARK: List

            ("tag LIST INBOX \"\"", [.command(.init(tag: "tag", command: .list(nil, reference: .inbox, .mailbox(""))))]),
            ("tag LIST /Mail/ %", [.command(.init(tag: "tag", command: .list(nil, reference: .init("/Mail/"), .mailbox("%"))))]),

            // MARK: LSUB

            ("tag LSUB INBOX \"\"", [.command(.init(tag: "tag", command: .lsub(reference: .inbox, pattern: "")))]),

            // MARK: Status

            ("tag STATUS INBOX (MESSAGES)", [.command(.init(tag: "tag", command: .status(.inbox, [.messageCount])))]),
            ("tag STATUS INBOX (MESSAGES RECENT UIDNEXT)", [.command(.init(tag: "tag", command: .status(.inbox, [.messageCount, .recentCount, .uidNext])))]),

            // MARK: Append

            ("tag APPEND box (\\Seen) {1+}\r\na", [
                .append(.start(tag: "tag", appendingTo: .init("box"))),
                .append(.beginMessage(message: .init(options: .init(flagList: [.seen], extensions: [:]), data: .init(byteCount: 1)))),
                .append(.messageBytes("a")),
                .append(.endMessage),
                .append(.finish),
            ]),
        ]

        let input = inoutPairs.map { ($0.0 + CRLF, $0.1.map { PartialCommandStream($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: input,
                decoderFactory: { () -> CommandDecoder in
                    CommandDecoder()
                }
            )
        } catch let error as ByteToMessageDecoderVerifier.VerificationError<PartialCommandStream> {
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

            ("* BYE logging off", [.untaggedResponse(.conditionalState(.bye(.init(code: nil, text: "logging off"))))]),
            ("* BYE [ALERT] logging off", [.untaggedResponse(.conditionalState(.bye(.init(code: .alert, text: "logging off"))))]),

            // MARK: Capability

            ("* CAPABILITY IMAP4rev1 CHILDREN CONDSTORE", [.untaggedResponse(.capabilityData([.imap4rev1, .children, .condStore]))]),
            // With trailing space:
            ("* CAPABILITY IMAP4rev1 CHILDREN CONDSTORE ", [.untaggedResponse(.capabilityData([.imap4rev1, .children, .condStore]))]),

            // MARK: LIST

            ("* LIST (\\noselect) \"/\" ~/Mail/foo", [.untaggedResponse(.mailboxData(.list(.init(attributes: [.noSelect], path: try! .init(name: .init("~/Mail/foo"), pathSeparator: "/"), extensions: [:]))))]),

            // MARK: LSUB

            ("* LSUB (\\noselect) \"/\" ~/Mail/foo", [.untaggedResponse(.mailboxData(.lsub(.init(attributes: [.noSelect], path: try! .init(name: .init("~/Mail/foo"), pathSeparator: "/"), extensions: [:]))))]),

            // MARK: Status

            ("* STATUS INBOX (MESSAGES 231 UIDNEXT 44292)", [.untaggedResponse(.mailboxData(.status(.inbox, .init(messageCount: 231, nextUID: 44292))))]),

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

        let inputs = inoutPairs.map { ($0.0 + CRLF, $0.1.map { ResponseOrContinuationRequest.response($0) }) }
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inputs,
                decoderFactory: { () -> ResponseDecoder in
                    ResponseDecoder()
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
