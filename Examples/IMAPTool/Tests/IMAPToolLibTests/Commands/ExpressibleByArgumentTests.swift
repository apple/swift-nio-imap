//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
@testable import IMAPToolLib
import Foundation
import NIO
import NIOIMAP
import SystemPackage
import Testing

private struct ArgumentFixture<A: ExpressibleByArgument & Equatable & Sendable>: Sendable {
    var input: String
    var expected: A?
}

@Suite
private enum ExpressibleByArgumentTests {
    @Test(arguments: [
        ArgumentFixture<MessageID>(
            input: "<foo@apple.com>",
            expected: MessageID("<foo@apple.com>")
        ),
        ArgumentFixture<MessageID>(
            input: "foo@apple.com",
            expected: MessageID("<foo@apple.com>")
        ),
        ArgumentFixture<MessageID>(
            input: "<foo@apple.com",
            expected: nil
        ),
        ArgumentFixture<MessageID>(
            input: "foo@apple.com>",
            expected: nil
        ),
        ArgumentFixture<MessageID>(
            input: "",
            expected: nil
        ),
        ArgumentFixture<MessageID>(
            input: "   ",
            expected: nil
        ),
        ArgumentFixture<MessageID>(
            input: "<>",
            expected: nil
        ),
    ])
    static func messageID(
        fixture: ArgumentFixture<MessageID>
    ) {
        if let expected = fixture.expected {
            #expect(MessageID(argument: fixture.input) == expected)
        } else {
            #expect(MessageID(argument: fixture.input) == nil)
        }
    }

    @Test(arguments: [
        ArgumentFixture<MailboxName>(
            input: "INBOX",
            expected: try? MailboxPath.makeRootMailbox(displayName: "INBOX").name
        ),
        ArgumentFixture<MailboxName>(
            input: "Sent",
            expected: try? MailboxPath.makeRootMailbox(displayName: "Sent").name
        ),
        ArgumentFixture<MailboxName>(
            input: "Archive/2024",
            expected: try? MailboxPath.makeRootMailbox(displayName: "Archive/2024").name
        ),
    ])
    static func mailboxName(
        fixture: ArgumentFixture<MailboxName>
    ) {
        if let expected = fixture.expected {
            #expect(MailboxName(argument: fixture.input) == expected)
        } else {
            #expect(MailboxName(argument: fixture.input) == nil)
        }
    }

    @Test(arguments: [
        ArgumentFixture<FilePath>(
            input: "/path/to/file",
            expected: FilePath("/path/to/file")
        ),
        ArgumentFixture<FilePath>(
            input: "relative/path",
            expected: FilePath("relative/path")
        ),
        ArgumentFixture<FilePath>(
            input: "",
            expected: FilePath("")
        ),
    ])
    static func filePath(
        fixture: ArgumentFixture<FilePath>
    ) {
        if let expected = fixture.expected {
            #expect(FilePath(argument: fixture.input) == expected)
        } else {
            #expect(FilePath(argument: fixture.input) == nil)
        }
    }

    @Test(arguments: [
        ArgumentFixture<UID>(
            input: "1",
            expected: UID(exactly: 1)
        ),
        ArgumentFixture<UID>(
            input: "42",
            expected: UID(exactly: 42)
        ),
        ArgumentFixture<UID>(
            input: "4294967295",
            expected: UID(exactly: 4_294_967_295)
        ),
        ArgumentFixture<UID>(
            input: "0",
            expected: nil
        ),
        ArgumentFixture<UID>(
            input: "-1",
            expected: nil
        ),
        ArgumentFixture<UID>(
            input: "abc",
            expected: nil
        ),
        ArgumentFixture<UID>(
            input: "4294967296",
            expected: nil
        ),
    ])
    static func uid(
        fixture: ArgumentFixture<UID>
    ) {
        if let expected = fixture.expected {
            #expect(UID(argument: fixture.input) == expected)
        } else {
            #expect(UID(argument: fixture.input) == nil)
        }
    }

    @Test(arguments: [
        ArgumentFixture<RecordSeparator>(input: "1e", expected: .recordSeparator),
        ArgumentFixture<RecordSeparator>(input: "rs", expected: .recordSeparator),
        ArgumentFixture<RecordSeparator>(input: "recordSeparator", expected: .recordSeparator),
        ArgumentFixture<RecordSeparator>(input: "json-seq", expected: .recordSeparator),
        ArgumentFixture<RecordSeparator>(input: "0a", expected: .lineFeed),
        ArgumentFixture<RecordSeparator>(input: "lf", expected: .lineFeed),
        ArgumentFixture<RecordSeparator>(input: "linefeed", expected: .lineFeed),
        // Case-insensitive: these used to fail because the labels were mixed-case.
        ArgumentFixture<RecordSeparator>(input: "lineFeed", expected: .lineFeed),
        ArgumentFixture<RecordSeparator>(input: "LINEFEED", expected: .lineFeed),
        ArgumentFixture<RecordSeparator>(input: "0d", expected: .carriageReturn),
        ArgumentFixture<RecordSeparator>(input: "cr", expected: .carriageReturn),
        ArgumentFixture<RecordSeparator>(input: "carriageReturn", expected: .carriageReturn),
        ArgumentFixture<RecordSeparator>(input: "carriagereturn", expected: .carriageReturn),
        ArgumentFixture<RecordSeparator>(input: "", expected: nil),
        ArgumentFixture<RecordSeparator>(input: "nope", expected: nil),
    ])
    static func recordSeparator(
        fixture: ArgumentFixture<RecordSeparator>
    ) {
        #expect(RecordSeparator(argument: fixture.input) == fixture.expected)
    }
}
