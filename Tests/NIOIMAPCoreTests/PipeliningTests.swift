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

// MARK: -

final class PipeliningTests: XCTestCase {
}

extension PipeliningTests {
    func AssertCanStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssert(behavior.satisfies(requirements), file: file, line: line)
    }

    func AssertCanNotStart(_ requirements: Set<PipeliningRequirement>, whileRunning behavior: Set<PipeliningBehavior>, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(behavior.satisfies(requirements), file: file, line: line)
    }

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
    func testCommandRequires_noMailboxCommandsRunning() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningRequirements.contains(.noMailboxCommandsRunning), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .select(.food),
                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningRequirements.contains(.noMailboxCommandsRunning), "\(command)")
            }
        }
    }

    func testCommandRequires_noUntaggedExpungeResponse() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .select(.food),
                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: []),
                .uidSearch(key: .uid(.set([1])), charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningRequirements.contains(.noUntaggedExpungeResponse), "\(command)")
            }
        }
        do {
            // All commands that reference messages by sequence numbers have this requirement:
            let commands: [Command] = [
                .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningRequirements.contains(.noUntaggedExpungeResponse), "\(command)")
            }
        }
    }

    func testCommandRequires_noUIDBasedCommandRunning() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .select(.food),
                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: []),
                .uidSearch(key: .uid(.set([1])), charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningRequirements.contains(.noUIDBasedCommandRunning), "\(command)")
            }
        }
        do {
            // Must wait for a completion of UID commands
            // before sending a command with message sequence numbers.
            let commands: [Command] = [
                .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningRequirements.contains(.noUIDBasedCommandRunning), "\(command)")
            }
        }
    }

    func testCommandRequires_noFlagChanges() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .select(.food),
                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: []),
                .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningRequirements.contains(.noFlagChanges), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .uidSearch(key: .answered, charset: nil, returnOptions: []),
                .uidSearch(key: .unanswered, charset: nil, returnOptions: []),
                .uidSearch(key: .seen, charset: nil, returnOptions: []),
                .uidSearch(key: .unseen, charset: nil, returnOptions: []),
                .uidSearch(key: .keyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .flagged, charset: nil, returnOptions: []),
                .uidSearch(key: .unflagged, charset: nil, returnOptions: []),
                .uidSearch(key: .deleted, charset: nil, returnOptions: []),
                .uidSearch(key: .undeleted, charset: nil, returnOptions: []),
                .uidSearch(key: .draft, charset: nil, returnOptions: []),
                .uidSearch(key: .undraft, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .fetch(.set([1]), [.uid, .flags], [:]),
                .uidFetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .uidFetch(.set([1]), [.uid, .flags], [:]),
                // This will also return flags:
                .uidStore(.set([1]), [:], .add(silent: false, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningRequirements.contains(.noFlagChanges), "\(command)")
            }
        }
    }

    func testCommandRequires_noFlagReads() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .select(.food),
                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .answered, charset: nil, returnOptions: []),
                .uidSearch(key: .unanswered, charset: nil, returnOptions: []),
                .uidSearch(key: .seen, charset: nil, returnOptions: []),
                .uidSearch(key: .unseen, charset: nil, returnOptions: []),
                .uidSearch(key: .keyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: []),
                .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: []),
                .uidSearch(key: .deleted, charset: nil, returnOptions: []),
                .uidSearch(key: .undeleted, charset: nil, returnOptions: []),
                .uidSearch(key: .draft, charset: nil, returnOptions: []),
                .uidSearch(key: .undraft, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .fetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .fetch(.set([1]), [.uid, .flags], [:]),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidFetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .uidFetch(.set([1]), [.uid, .flags], [:]),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningRequirements.contains(.noFlagReads), "\(command)")
            }
        }
        do {
            // Must wait for a completion of UID commands
            // before sending a command with message sequence numbers.
            let commands: [Command] = [
                .uidStore(.set([1]), [:], .add(silent: false, list: [.answered])),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningRequirements.contains(.noFlagReads), "\(command)")
            }
        }
    }
}

// MARK: Command Behavior

extension PipeliningTests {
    func testCommandBehavior_changesMailboxSelection() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .check,
                .close,
                .expunge,
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.changesMailboxSelection), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .select(.food),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.changesMailboxSelection), "\(command)")
            }
        }
    }

    func testCommandBehavior_dependsOnMailboxSelection() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.dependsOnMailboxSelection), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .check,
                .expunge,
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.dependsOnMailboxSelection), "\(command)")
            }
        }
    }

    func testCommandBehavior_mayTriggerUntaggedExpunge() {
        // All commands, except for FETCH, STORE, and SEARCH can
        // trigger an untagged EXPUNGE.
        do {
            let commands: [Command] = [
                // These are not listed by the specs, but really can’t
                // trigger an expunge, because no mailbox is selected, yet.
                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                // FETCH, SEARCH
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.mayTriggerUntaggedExpunge), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),

                .check,
                .expunge,
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.mayTriggerUntaggedExpunge), "\(command)")
            }
        }
    }

    func testCommandBehavior_isUIDBased() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),

                .check,
                .expunge,
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.isUIDBased), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.isUIDBased), "\(command)")
            }
        }
    }

    func testCommandBehavior_changesFlags() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),

                .check,
                .expunge,
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.changesFlags), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
                .uidStore(.set([1]), [:], .add(silent: false, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.changesFlags), "\(command)")
            }
        }
    }

    func testCommandBehavior_readsFlags() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),

                .check,
                .expunge,
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.readsFlags), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .uidStore(.set([1]), [:], .add(silent: false, list: [.answered])),
                .uidSearch(key: .keyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .unkeyword("A"), charset: nil, returnOptions: []),
                .uidSearch(key: .answered, charset: nil, returnOptions: []),
                .uidSearch(key: .unanswered, charset: nil, returnOptions: []),
                .uidSearch(key: .seen, charset: nil, returnOptions: []),
                .uidSearch(key: .unseen, charset: nil, returnOptions: []),
                .uidSearch(key: .flagged, charset: nil, returnOptions: []),
                .uidSearch(key: .unflagged, charset: nil, returnOptions: []),
                .uidSearch(key: .deleted, charset: nil, returnOptions: []),
                .uidSearch(key: .undeleted, charset: nil, returnOptions: []),
                .uidSearch(key: .draft, charset: nil, returnOptions: []),
                .uidSearch(key: .undraft, charset: nil, returnOptions: []),
                .fetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .fetch(.set([1]), [.uid, .flags], [:]),
                .uidFetch(.set([1]), [.envelope, .uid, .flags], [:]),
                .uidFetch(.set([1]), [.uid, .flags], [:]),
                // This will also return flags:
                .uidStore(.set([1]), [:], .add(silent: false, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.readsFlags), "\(command)")
            }
        }
    }

    func testCommandBehavior_barrier() {
        do {
            let commands: [Command] = [
                .capability,
                .noop,

                .login(username: "user", password: "password"),

                .delete(.food),
                .rename(from: .food, to: .food, params: [:]),
                .examine(.food),
                .create(.food, []),
                .list(nil, reference: .food, .food, []),
                .status(.food, [.messageCount]),
                //.append(into: .food, flags: [], date: nil, message: Data()),
                .close,
                .select(.food),

                .check,
                .expunge,
                .fetch(.set([1]), [.envelope, .uid], [:]),
                .fetch(.set([1]), [.bodyStructure(extensions: false)], [:]),
                .uidSearch(key: .all, charset: nil, returnOptions: []),
                .uidFetch(.set([1]), [.envelope, .uid], [:]),
                .uidCopy(.set([1]), .food),
                .uidMove(.set([1]), .food),
                .uidStore(.set([1]), [:], .add(silent: true, list: [.answered])),
            ]

            commands.forEach { command in
                XCTAssertFalse(command.pipeliningBehavior.contains(.barrier), "\(command)")
            }
        }
        do {
            let commands: [Command] = [
                .starttls,
                .authenticate(mechanism: .plain, initialResponse: nil),
            ]

            commands.forEach { command in
                XCTAssert(command.pipeliningBehavior.contains(.barrier), "\(command)")
            }
        }
    }
}
