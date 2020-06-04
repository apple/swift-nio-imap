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
@testable import NIOIMAPCore
import NIOTestUtils

import XCTest

final class RoundtripTests: XCTestCase {
    func testClientRountrip() {
        // 1 AUTHENTICATE type\r\n1111\r\n2222\r\n

        let tests: [(Command, UInt)] = [
            (.noop, #line),
            (.capability, #line),
            (.logout, #line),
            (.starttls, #line),
            (.check, #line),
            (.close, #line),
            (.expunge, #line),

            (.login(username: "user", password: "password"), #line),

            (.authenticate(method: "some", nil, []), #line),
            (.authenticate(method: "some", .equals, []), #line),

            (.create(.inbox, []), #line),
            (.create(MailboxName("mailbox"), []), #line),

            (.delete(.inbox), #line),
            (.delete(MailboxName("mailbox")), #line),

            (.examine(.inbox, []), #line),
            (.examine(MailboxName("mailbox"), []), #line),
            (.examine(MailboxName("mailbox")), #line),

            (.subscribe(.inbox), #line),
            (.subscribe(MailboxName("mailbox")), #line),

            (.unsubscribe(.inbox), #line),
            (.unsubscribe(MailboxName("mailbox")), #line),

            (.select(.inbox, []), #line),
            (.select(MailboxName("mailbox"), []), #line),
            (.select(MailboxName("mailbox")), #line),

            (.rename(from: .inbox, to: .inbox, params: []), #line),
            (.rename(from: MailboxName("test1"), to: MailboxName("test2"), params: []), #line),

            (.append(to: .inbox, firstMessageMetadata: .init(options: .init(flagList: [.answered], dateTime: nil, extensions: []), data: .init(byteCount: 5))), #line),
            (.append(to: MailboxName("test1"), firstMessageMetadata: .init(options: .init(flagList: [.answered, .deleted, .draft], dateTime: nil, extensions: []), data: .init(byteCount: 5))), #line),

            (.list(nil, reference: .inbox, .pattern(["pattern"]), []), #line),
            (.list(nil, reference: MailboxName("bar"), .pattern(["pattern"]), []), #line),
            (.list(reference: .inbox, .mailbox("pattern")), #line),

            (.lsub(reference: .inbox, pattern: "abcd"), #line),
            (.lsub(reference: .inbox, pattern: "\"something\""), #line),
            (.lsub(reference: MailboxName("bar"), pattern: "{3}\r\nfoo"), #line),

            (.status(.inbox, [.messageCount]), #line),
            (.status(MailboxName("foobar"), [.messageCount, .recentCount, .uidNext]), #line),

            (.copy(SequenceSet(2...), .inbox), #line),

            (.fetch([.all], .all, []), #line),
            (.fetch([.all], .fast, []), #line),
            (.fetch([.all], .full, []), #line),
            (.fetch([5678], [.uid, .flags, .internalDate, .envelope], []), #line),
            (.fetch([5678], [.flags, .bodyStructure(extensions: true)], []), #line),
            (.fetch([5678], [.flags, .bodySection(peek: false, nil, 3 ... 4)], []), #line),
            (.fetch([5678], [.flags, .bodySection(peek: false, .init(kind: .header), 3 ... 4)], []), #line),
            (.fetch([5678], [.bodySection(peek: false, .init(part: [12, 34], kind: .headerFields(["some", "header"])), 3 ... 4)], []), #line),

            (.store(.all, [], .remove(silent: true, list: [.answered, .deleted])), #line),
            (.store(.all, [], .add(silent: true, list: [.draft, .extension("\\some")])), #line),
            (.store(.all, [], .replace(silent: true, list: [.keyword(.colorBit0)])), #line),

            (.uidCopy(.all, .inbox), #line),

            (.uidStore(.all, [], .add(silent: true, list: [.draft, .deleted, .answered])), #line),

            (.search(returnOptions: [.all], program: .init(charset: nil, keys: [.all])), #line),
        ]

        for (i, test) in tests.enumerated() {
            var encodeBuffer = EncodeBuffer(ByteBufferAllocator().buffer(capacity: 128), mode: .client, capabilities: [])
            let commandType = test.0
            let line = test.1
            let tag = "\(i + 1)"
            let command = TaggedCommand(tag: tag, command: commandType)
            encodeBuffer.writeCommand(command)
            encodeBuffer.writeString("\r\n") // required for commands that might terminate with a literal (e.g. append)
            var buffer = ByteBufferAllocator().buffer(capacity: 128)
            while true {
                let next = encodeBuffer.nextChunk()
                var toSend = next.bytes
                buffer.writeBuffer(&toSend)
                if !next.waitForContinuation {
                    break
                }
            }
            do {
                let decoded = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(command, decoded, line: line)
            } catch {
                XCTFail("\(error) - \(buffer.readString(length: buffer.readableBytesView.count)!)", line: line)
            }
            buffer.clear()
        }
    }
}
