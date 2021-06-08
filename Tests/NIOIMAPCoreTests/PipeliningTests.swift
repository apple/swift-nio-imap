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
import XCTest

extension MailboxName {
    fileprivate static let food = MailboxName(ByteBuffer(string: "Food"))
}

extension MailboxPatterns {
    fileprivate static let food = MailboxPatterns.mailbox(ByteBuffer(string: "Food"))
}

extension RumpURLAndMechanism {
    fileprivate static let joe = RumpURLAndMechanism(urlRump: "imap://joe@example.com/INBOX/;uid=20/;section=1.2", mechanism: .internal)
}

extension ByteBuffer {
    fileprivate static let joeURLFetch = ByteBuffer("imap://joe@example.com/INBOX/;uid=20/;section=1.2;urlauth=submit+fred:internal:91354a473744909de610943775f92038")
}

extension SearchKey {
    fileprivate static let keysWithoutSequenceNumber: [SearchKey] = [
        .bcc("foo"),
        .uid(.set([1])),
        .answered,
        .subject("foo"),
        .or(.unseen, .uid(.set([1]))),
    ]

    fileprivate static let keysWithSequenceNumber: [SearchKey] = [
        .sequenceNumbers(.set([1])),
        .or(.unseen, .sequenceNumbers(.set([1]))),
        .or(.uid(.set([1])), .sequenceNumbers(.set([1]))),
        .and([.unseen, .sequenceNumbers(.set([1]))]),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))]),
    ]

    fileprivate static let keysWithoutUID: [SearchKey] = [
        .bcc("foo"),
        .sequenceNumbers(.set([1])),
        .answered,
        .subject("foo"),
        .or(.unseen, .sequenceNumbers(.set([1]))),
    ]

    fileprivate static let keysWithUID: [SearchKey] = [
        .uid(.set([1])),
        .or(.unseen, .uid(.set([1]))),
        .or(.uid(.set([1])), .sequenceNumbers(.set([1]))),
        .and([.unseen, .uid(.set([1]))]),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))]),
    ]

    fileprivate static let keysWithoutFlags: [SearchKey] = [
        .sequenceNumbers(.set([1])),
        .uid(.set([1])),
        .bcc("foo"),
        .uid(.set([1])),
        .subject("foo"),
        .or(.bcc("foo"), .uid(.set([1]))),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))]),
    ]

    fileprivate static let keysWithFlags: [SearchKey] = [
        .answered,
        .unanswered,
        .seen,
        .unseen,
        .keyword("A"),
        .unkeyword("A"),
        .flagged,
        .unflagged,
        .deleted,
        .undeleted,
        .draft,
        .undraft,
        .or(.answered, .uid(.set([1]))),
        .and([.answered, .sequenceNumbers(.set([1]))]),
    ]

    fileprivate static let arbitraryKeys: [SearchKey] = [
        .bcc("foo"),
        .uid(.set([1])),
        .answered,
        .subject("foo"),
        .answered,
        .unanswered,
        .seen,
        .unseen,
        .keyword("A"),
        .unkeyword("A"),
        .flagged,
        .unflagged,
        .deleted,
        .undeleted,
        .draft,
        .undraft,
        .uid(.set([1])),
        .sequenceNumbers(.set([1])),
        .or(.answered, .uid(.set([1]))),
        .and([.answered, .sequenceNumbers(.set([1]))]),
        .or(.unseen, .uid(.set([1]))),
        .or(.unseen, .sequenceNumbers(.set([1]))),
        .or(.uid(.set([1])), .sequenceNumbers(.set([1]))),
        .and([.unseen, .sequenceNumbers(.set([1]))]),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))]),
    ]
}

// MARK: -

fileprivate func AssertCanStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(behavior.satisfies(requirements), file: file, line: line)
}

fileprivate func AssertCanNotStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(behavior.satisfies(requirements), file: file, line: line)
}

fileprivate func AssertFalse(commands: [(UInt, Command)], require requirement: PipeliningRequirement, _ message: @autoclosure () -> String = "", file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssertFalse(command.pipeliningRequirements.contains(requirement), "Should not require \(requirement). \(message())", file: file, line: line)
    }
}

fileprivate func Assert(commands: [(UInt, Command)], require requirement: PipeliningRequirement, _ message: @autoclosure () -> String = "", file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssert(command.pipeliningRequirements.contains(requirement), "Should require \(requirement). \(message())", file: file, line: line)
    }
}

fileprivate func AssertFalse(commands: [(UInt, Command)], haveBehavior behavior: PipeliningBehavior, _ message: @autoclosure () -> String = "", file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssertFalse(command.pipeliningBehavior.contains(behavior), "Should not have \(behavior) behavior. \(message())", file: file, line: line)
    }
}

fileprivate func Assert(commands: [(UInt, Command)], haveBehavior behavior: PipeliningBehavior, _ message: @autoclosure () -> String = "", file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssert(command.pipeliningBehavior.contains(behavior), "Should have \(behavior) behavior. \(message())", file: file, line: line)
    }
}

// MARK: -

final class PipeliningTests: XCTestCase {}

// MARK: Interaction of Requirements and Behavior

extension PipeliningTests {
    func testCanStartEmptyBehavior() {
        // When the running command doesn’t have any requirements, anything can run:
        AssertCanStart([],
                       whileRunning: [])
        AssertCanStart([.noMailboxCommandsRunning],
                       whileRunning: [])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [])
        AssertCanStart([.noFlagReads],
                       whileRunning: [])
        AssertCanStart(Set(PipeliningRequirement.allCases),
                       whileRunning: [])
    }

    func testCanStartChangesMailboxSelectionBehavior() {
        AssertCanStart([],
                       whileRunning: [.changesMailboxSelection])
        // Don’t start a command that depends on the selected state
        // while changing the selected state.
        AssertCanNotStart([.noMailboxCommandsRunning],
                          whileRunning: [.changesMailboxSelection])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [.changesMailboxSelection])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [.changesMailboxSelection])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [.changesMailboxSelection])
        AssertCanStart([.noFlagReads],
                       whileRunning: [.changesMailboxSelection])

        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.changesMailboxSelection])
    }

    func testCanStartDependsOnMailboxSelectionBehavior() {
        AssertCanStart([],
                       whileRunning: [.dependsOnMailboxSelection])
        // Don’t start a command that requires no mailbox-specific commands,
        // while mailbox-specific commands are running. E.g. don’t change the
        // mailbox while running a FETCH.
        AssertCanNotStart([.noMailboxCommandsRunning],
                          whileRunning: [.dependsOnMailboxSelection])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [.dependsOnMailboxSelection])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [.dependsOnMailboxSelection])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [.dependsOnMailboxSelection])
        AssertCanStart([.noFlagReads],
                       whileRunning: [.dependsOnMailboxSelection])

        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.dependsOnMailboxSelection])
    }

    func testCanStartMayTriggerUntaggedExpungeBehavior() {
        AssertCanStart([],
                       whileRunning: [.mayTriggerUntaggedExpunge])
        AssertCanStart([.noMailboxCommandsRunning],
                       whileRunning: [.mayTriggerUntaggedExpunge])
        // If a command may trigger “untagged EXPUNGE”, don’t start a command
        // that requires this not to happen.
        AssertCanNotStart([.noUntaggedExpungeResponse],
                          whileRunning: [.mayTriggerUntaggedExpunge])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [.mayTriggerUntaggedExpunge])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [.mayTriggerUntaggedExpunge])
        AssertCanStart([.noFlagReads],
                       whileRunning: [.mayTriggerUntaggedExpunge])

        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.mayTriggerUntaggedExpunge])
    }

    func testCanStartIsUIDBasedBehavior() {
        AssertCanStart([],
                       whileRunning: [.isUIDBased])
        AssertCanStart([.noMailboxCommandsRunning],
                       whileRunning: [.isUIDBased])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [.isUIDBased])
        AssertCanNotStart([.noUIDBasedCommandRunning],
                          whileRunning: [.isUIDBased])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [.isUIDBased])
        AssertCanStart([.noFlagReads],
                       whileRunning: [.isUIDBased])
        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.isUIDBased])
    }

    func testCanStartChangesFlagsBehavior() {
        AssertCanStart([],
                       whileRunning: [.changesFlags])
        AssertCanStart([.noMailboxCommandsRunning],
                       whileRunning: [.changesFlags])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [.changesFlags])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [.changesFlags])
        AssertCanNotStart([.noFlagChanges],
                          whileRunning: [.changesFlags])
        AssertCanStart([.noFlagReads],
                       whileRunning: [.changesFlags])
        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.changesFlags])
    }

    func testCanStartReadsFlagsBehavior() {
        AssertCanStart([],
                       whileRunning: [.readsFlags])
        AssertCanStart([.noMailboxCommandsRunning],
                       whileRunning: [.readsFlags])
        AssertCanStart([.noUntaggedExpungeResponse],
                       whileRunning: [.readsFlags])
        AssertCanStart([.noUIDBasedCommandRunning],
                       whileRunning: [.readsFlags])
        AssertCanStart([.noFlagChanges],
                       whileRunning: [.readsFlags])
        AssertCanNotStart([.noFlagReads],
                          whileRunning: [.readsFlags])
        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.readsFlags])
    }

    func testCanStartBarrierBehavior() {
        // Nothing can be started, while a barrier is running.
        AssertCanNotStart([],
                          whileRunning: [.barrier])
        AssertCanNotStart([.noMailboxCommandsRunning],
                          whileRunning: [.barrier])
        AssertCanNotStart([.noUntaggedExpungeResponse],
                          whileRunning: [.barrier])
        AssertCanNotStart([.noUIDBasedCommandRunning],
                          whileRunning: [.barrier])
        AssertCanNotStart([.noFlagChanges],
                          whileRunning: [.barrier])
        AssertCanNotStart([.noFlagReads],
                          whileRunning: [.barrier])
        AssertCanNotStart(Set(PipeliningRequirement.allCases),
                          whileRunning: [.barrier])
    }
}

// MARK: Command Requirements

extension PipeliningTests {
    func testAppend() {
        XCTFail()
    }

    func testCommandRequires_noMailboxCommandsRunning() {
        // Which commands have the requirements that:
        // > No command that depend on the _Selected State_ must be running.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),

            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),

            (#line, .create(.food, [])),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),

            (#line, .status(.food, [.messageCount])),
            (#line, .copy(.set([1]), .food)),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .check),
            (#line, .expunge),
            (#line, .uidExpunge(.set([1]))),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),

            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),

            (#line, .idleStart),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], require: .noMailboxCommandsRunning)

        Assert(commands: [
            (#line, .examine(.food)),
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .close),
        ], require: .noMailboxCommandsRunning)
    }

    func testCommandRequires_noUntaggedExpungeResponse() {
        // Which commands have the requirements that:
        // > No command besides `FETCH`, `STORE`, and `SEARCH` is running.
        // This is a requirement for all sequence number based commands.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .unselect),
            (#line, .idleStart),

            (#line, .id([:])),
            (#line, .namespace),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .select(.food)),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .status(.food, [.messageCount])),
            //(#line, .append(into: .food, flags: [], date: nil, message: Data()))),
            (#line, .check),
            (#line, .close),
            (#line, .expunge),
            (#line, .uidExpunge(.set([1]))),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
        ], require: .noUntaggedExpungeResponse)

        // All commands that reference messages by sequence numbers have this requirement:
        Assert(commands: [
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
        ], require: .noUntaggedExpungeResponse)

        // SEARCH, ESEARCH, and UID SEARCH
        // only have this requirement if a search key references sequence numbers.
        SearchKey.keysWithoutSequenceNumber.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noUntaggedExpungeResponse, "key: \(key)")
        }
        SearchKey.keysWithSequenceNumber.forEach { key in
            Assert(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noUntaggedExpungeResponse, "key: \(key)")
        }
    }

    func testCommandRequires_noUIDBasedCommandRunning() {
        // Which commands have the requirements that:
        // > No command is running that uses UIDs to specify messages.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .unselect),
            (#line, .idleStart),

            (#line, .id([:])),
            (#line, .namespace),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .select(.food)),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .check),
            (#line, .close),
            (#line, .expunge),
            (#line, .uidExpunge(.set([1]))),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .bcc("foo")))),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .uid(.set([1]))))),
            (#line, .search(key: .bcc("foo"), charset: nil, returnOptions: [])),
            (#line, .search(key: .uid(.set([1])), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .uid(.set([1])), charset: nil, returnOptions: [])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
        ], require: .noUIDBasedCommandRunning)

        // All commands that reference messages by sequence numbers have this requirement:
        Assert(commands: [
            (#line, .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [])),
            (#line, .search(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [.all])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .sequenceNumbers(.set([1]))))),

            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
        ], require: .noUIDBasedCommandRunning)


        // SEARCH, ESEARCH, and UID SEARCH
        // only have this requirement if a search key references sequence numbers.
        SearchKey.keysWithoutSequenceNumber.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noUIDBasedCommandRunning, "key: \(key)")
        }
        SearchKey.keysWithSequenceNumber.forEach { key in
            Assert(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noUIDBasedCommandRunning, "key: \(key)")
        }
    }

    func testCommandRequires_noFlagChanges() {
        // Which commands have the requirements that:
        // > No STORE command is running.
        // (i.e. no flags are being changed)

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),

            (#line, .logout),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .unselect),
            (#line, .idleStart),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .uidExpunge(.set([1]))),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .select(.food)),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .check),
            (#line, .close),
            (#line, .expunge),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            // STORE is ok if SILENT is set:
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
        ], require: .noFlagChanges)

        Assert(commands: [
            // FETCH that return flags:
            (#line, .fetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .fetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.uid, .flags], [:])),
            // STORE without SILENT will also return flags:
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
        ], require: .noFlagChanges)

        // SEARCH, ESEARCH, and UID SEARCH have this requirement only if they
        // reference flags:
        SearchKey.keysWithoutFlags.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noFlagChanges, "key: \(key)")
        }
        SearchKey.keysWithFlags.forEach { key in
            Assert(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noFlagChanges, "key: \(key)")
        }
    }

    func testCommandRequires_noFlagReads() {
        // Which commands have the requirements that:
        /// > No command is running that retrieves flags.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .unselect),
            (#line, .idleStart),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .uidExpunge(.set([1]))),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .select(.food)),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),

            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .check),
            (#line, .close),
            (#line, .expunge),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .fetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .fetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
        ], require: .noFlagReads)

        // STORE / UID STORE are the only ones with this requirement:
        Assert(commands: [
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
        ], require: .noFlagReads)

        // SEARCH, ESEARCH, and UID SEARCH never have this requirement.
        SearchKey.arbitraryKeys.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], require: .noFlagChanges, "key: \(key)")
        }
    }
}

// MARK: Command Behavior

extension PipeliningTests {
    func testCommandBehavior_changesMailboxSelection() {
        /// Commands that change the _mailbox selection_.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),

            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .idleStart),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .uidExpunge(.set([1]))),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .create(.food, [])),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .check),
            (#line, .expunge),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
        ], haveBehavior: .changesMailboxSelection)

        Assert(commands: [
            (#line, .select(.food)),
            (#line, .examine(.food)),
            (#line, .unselect),
            (#line, .close),
        ], haveBehavior: .changesMailboxSelection)
    }

    func testCommandBehavior_dependsOnMailboxSelection() {
        /// Commands that depend on the _mailbox selection_.

        AssertFalse(commands: [
            (#line, .capability),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .enable([.condStore])),
            (#line, .id([:])),
            (#line, .namespace),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),

            (#line, .close),
            (#line, .select(.food)),
            (#line, .unselect),

            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),

            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),

            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], haveBehavior: .dependsOnMailboxSelection)

        Assert(commands: [
            (#line, .noop),
            (#line, .check),
            (#line, .uidExpunge(.set([1]))),
            (#line, .expunge),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .idleStart),
        ], haveBehavior: .dependsOnMailboxSelection)
    }

    func testCommandBehavior_mayTriggerUntaggedExpunge() {
        // All commands, except for FETCH, STORE, and SEARCH can
        // trigger an untagged EXPUNGE.
        AssertFalse(commands: [
            // FETCH, STORE, and SEARCH
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .search(key: .answered, charset: nil, returnOptions: [.all])),
            // Does not make sense for these:
            (#line, .login(username: "user", password: "password")),
            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .logout),
        ], haveBehavior: .mayTriggerUntaggedExpunge)

        Assert(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .close),
            (#line, .select(.food)),

            (#line, .check),
            (#line, .expunge),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),

            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .enable([.condStore])),
            (#line, .unselect),
            (#line, .idleStart),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .uidExpunge(.set([1]))),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], haveBehavior: .mayTriggerUntaggedExpunge)
    }

    func testCommandBehavior_isUIDBased() {
        /// Commands that use UIDs to specify messages.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .enable([.condStore])),
            (#line, .id([:])),
            (#line, .namespace),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data())),
            (#line, .close),
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .idleStart),

            (#line, .check),
            (#line, .expunge),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),

            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),

            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
        ], haveBehavior: .isUIDBased)

        Assert(commands: [
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .uidExpunge(.set([1]))),
            // `GENURLAUTH` and `URLFETCH` (indirectly) reference UIDs:
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], haveBehavior: .isUIDBased)

        SearchKey.keysWithoutUID.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
            ], haveBehavior: .isUIDBased, "key: \(key)")
            // UID SEARCH has this behavior even if the key does not
            // reference UIDs:
            Assert(commands: [
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], haveBehavior: .isUIDBased, "key: \(key)")
        }
        SearchKey.keysWithUID.forEach { key in
            Assert(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], haveBehavior: .isUIDBased, "key: \(key)")
        }
    }

    func testCommandBehavior_changesFlags() {
        /// Commands that change flags on messages.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .enable([.condStore])),
            (#line, .id([:])),
            (#line, .namespace),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data())),
            (#line, .close),
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .idleStart),

            (#line, .check),
            (#line, .expunge),
            (#line, .uidExpunge(.set([1]))),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),

            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], haveBehavior: .changesFlags)

        Assert(commands: [
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
        ], haveBehavior: .changesFlags)
    }

    func testCommandBehavior_readsFlags() {
        /// Command that are querying / reading flags.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .login(username: "user", password: "password")),
            (#line, .logout),
            (#line, .id([:])),
            (#line, .namespace),
            (#line, .idleStart),
            (#line, .enable([.condStore])),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .close),
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .check),
            (#line, .expunge),
            (#line, .uidExpunge(.set([1]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .copy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .subscribe(.food)),
            (#line, .unsubscribe(.food)),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            // TODO: Cleanup search
            // Search is ok as long as it doesn’t reference flags:
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .search(key: .all, charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),

            // STORE is ok as long as it is SILENT
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),

            // FETCH is ok as long as it’s not fetching flags:
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
        ], haveBehavior: .readsFlags)

        Assert(commands: [
            // This will also return flags:
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),

            (#line, .fetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .fetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.uid, .flags], [:])),
        ], haveBehavior: .readsFlags)

        // SEARCH, ESEARCH, and UID SEARCH have this behavior only if they
        // reference flags:
        SearchKey.keysWithoutFlags.forEach { key in
            AssertFalse(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], haveBehavior: .readsFlags, "key: \(key)")
        }
        SearchKey.keysWithFlags.forEach { key in
            Assert(commands: [
                (#line, .search(key: key, charset: nil, returnOptions: [])),
                (#line, .extendedsearch(ExtendedSearchOptions(key: key))),
                (#line, .uidSearch(key: key, charset: nil, returnOptions: [])),
            ], haveBehavior: .readsFlags, "key: \(key)")
        }
    }

    func testSearchReferencingUIDs() {
        // TODO
        XCTFail("TODO")
    }
    
    func testCommandBehavior_barrier() {
        /// No additional commands may be sent until these commands complete.

        AssertFalse(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .login(username: "user", password: "password")),

            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .list(nil, reference: .food, .food, [])),
            (#line, .listIndependent([], reference: .food, .food, [])),
            (#line, .lsub(reference: .food, pattern: "Food")),
            (#line, .unsubscribe(.food)),
            (#line, .subscribe(.food)),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .close),
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .enable([.condStore])),
            (#line, .id([:])),
            (#line, .namespace),

            (#line, .check),
            (#line, .expunge),
            (#line, .fetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .fetch(.set([1]), [.bodyStructure(extensions: false)], [:])),
            (#line, .uidSearch(key: .all, charset: nil, returnOptions: [])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .copy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .store(.set([1]), [], .add(silent: true, list: [.answered]))),
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .search(key: .all, charset: nil, returnOptions: [.all])),
            (#line, .uidExpunge(.set([1]))),
            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),
        ], haveBehavior: .barrier)

        Assert(commands: [
            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .logout),
            (#line, .idleStart),
        ], haveBehavior: .barrier)
    }
}
