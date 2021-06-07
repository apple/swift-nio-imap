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

// MARK: -

fileprivate func AssertCanStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(behavior.satisfies(requirements), file: file, line: line)
}

fileprivate func AssertCanNotStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(behavior.satisfies(requirements), file: file, line: line)
}

fileprivate func AssertFalse(commands: [(UInt, Command)], require requirement: PipeliningRequirement, file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssertFalse(command.pipeliningRequirements.contains(requirement), "Should not require \(requirement)", file: file, line: line)
    }
}

fileprivate func Assert(commands: [(UInt, Command)], require requirement: PipeliningRequirement, file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssert(command.pipeliningRequirements.contains(requirement), "Should require \(requirement)", file: file, line: line)
    }
}

fileprivate func AssertFalse(commands: [(UInt, Command)], haveBehavior behavior: PipeliningBehavior, file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssertFalse(command.pipeliningBehavior.contains(behavior), "Should not have \(behavior) behavior", file: file, line: line)
    }
}

fileprivate func Assert(commands: [(UInt, Command)], haveBehavior behavior: PipeliningBehavior, file: StaticString = #filePath) {
    commands.forEach { line, command in
        XCTAssert(command.pipeliningBehavior.contains(behavior), "Should have \(behavior) behavior", file: file, line: line)
    }
}

// MARK: -

final class PipeliningTests: XCTestCase {}

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

    func testSubscription() {
        XCTFail()
    }

    func testMetadata() {
        // special use
        //
        // Flags?!?
        XCTFail()
    }

    func testQuota() {
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

            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .status(.food, [.messageCount])),
            (#line, .copy(.set([1]), .food)),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .move(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .check),
            (#line, .close),
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
            (#line, .select(.food)),
            (#line, .unselect),
            (#line, .delete(.food)),
            (#line, .rename(from: .food, to: .food, params: [:])),
        ], require: .noMailboxCommandsRunning)
    }

    func testCommandRequires_noUntaggedExpungeResponse() {
        // Which commands have the requirements that:
        // > No command besides `FETCH`, `STORE`, and `SEARCH` is running.
        // This is a requirement for all sequence number based commands.

        XCTFail("Search / eSearch only have this requirement if a search key references sequence numbers.")

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
        ], require: .noUntaggedExpungeResponse)

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
        ], require: .noUntaggedExpungeResponse)
    }

    func testCommandRequires_noUIDBasedCommandRunning() {
        // Which commands have the requirements that:
        // > No command is running that uses UIDs to specify messages.

        XCTFail("Search / eSearch only have this requirement if a search key references sequence numbers.")

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
        ], require: .noUntaggedExpungeResponse)

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
        ], require: .noUntaggedExpungeResponse)
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

            // All search are ok as long as they don’t references flags:
            (#line, .search(key: .bcc("foo"), charset: nil, returnOptions: [])),
            (#line, .search(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .bcc("foo")))),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .sequenceNumbers(.set([1]))))),
        ], require: .noFlagChanges)

        Assert(commands: [
            // SEARCH, ESEARCH, and UID SEARCH have this requirement _if_ they
            // reference flags:
            // TODO: Fix SEARCH
            (#line, .search(key: .answered, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .answered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unanswered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .seen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unseen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .keyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .flagged, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unflagged, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .deleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undeleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .draft, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undraft, charset: nil, returnOptions: [])),
            // FETCH that return flags:
            (#line, .fetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .fetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.uid, .flags], [:])),
            // STORE without SILENT will also return flags:
            (#line, .store(.set([1]), [], .add(silent: false, list: [.answered]))),
            (#line, .uidStore(.set([1]), [:], .add(silent: false, list: [.answered]))),
        ], require: .noFlagChanges)
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
            (#line, .extendedsearch(ExtendedSearchOptions(key: .all))),
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
            // TODO: SEARCH vs. UID SEARCH
            (#line, .search(key: .answered, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .answered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unanswered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .seen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unseen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .keyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .deleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undeleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .draft, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undraft, charset: nil, returnOptions: [])),
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
            (#line, .examine(.food)),
            (#line, .create(.food, [])),
            (#line, .status(.food, [.messageCount])),
            //.append(into: .food, flags: [], date: nil, message: Data()),
            (#line, .check),
            (#line, .close),
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
            (#line, .unselect),
        ], haveBehavior: .changesMailboxSelection)
    }

    func testCommandBehavior_dependsOnMailboxSelection() {
        /// Commands that depend on the _mailbox selection_.

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
        ], haveBehavior: .mayTriggerUntaggedExpunge)

        Assert(commands: [
            (#line, .capability),
            (#line, .noop),

            (#line, .login(username: "user", password: "password")),
            (#line, .starttls),
            (#line, .authenticate(mechanism: .plain, initialResponse: nil)),
            (#line, .logout),

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

            // SEARCH etc. without UID:
            (#line, .search(key: .answered, charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .answered, charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .answered))),

            (#line, .resetKey(mailbox: nil, mechanisms: [.internal])),
            (#line, .generateAuthorizedURL([.joe])),
            (#line, .urlFetch([.joeURLFetch])),

            (#line, .getQuota(QuotaRoot("foo"))),
            (#line, .getQuotaRoot(.food)),
            (#line, .setQuota(QuotaRoot("foo"), [])),
            (#line, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
            (#line, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
        ], haveBehavior: .isUIDBased)

        Assert(commands: [
            // TODO: SEARCH etc.
            (#line, .search(key: .uid(.set([1])), charset: nil, returnOptions: [.all])),
            (#line, .uidSearch(key: .uid(.set([1])), charset: nil, returnOptions: [])),
            (#line, .extendedsearch(ExtendedSearchOptions(key: .uid(.set([1]))))),
            (#line, .uidFetch(.set([1]), [.envelope, .uid], [:])),
            (#line, .uidStore(.set([1]), [:], .add(silent: true, list: [.answered]))),
            (#line, .uidCopy(.set([1]), .food)),
            (#line, .uidMove(.set([1]), .food)),
            (#line, .uidExpunge(.set([1]))),
        ], haveBehavior: .isUIDBased)
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

            // TODO: 3 x SEARCH
            (#line, .uidSearch(key: .keyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .answered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unanswered, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .seen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unseen, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .flagged, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .unflagged, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .deleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undeleted, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .draft, charset: nil, returnOptions: [])),
            (#line, .uidSearch(key: .undraft, charset: nil, returnOptions: [])),

            (#line, .fetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .fetch(.set([1]), [.uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.envelope, .uid, .flags], [:])),
            (#line, .uidFetch(.set([1]), [.uid, .flags], [:])),
        ], haveBehavior: .readsFlags)
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
