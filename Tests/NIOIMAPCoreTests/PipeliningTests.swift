//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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
import Testing

extension MailboxName {
    fileprivate static let food = MailboxName(ByteBuffer(string: "Food"))
}

extension MailboxPatterns {
    fileprivate static let food = MailboxPatterns.mailbox(ByteBuffer(string: "Food"))
}

extension RumpURLAndMechanism {
    fileprivate static let joe = RumpURLAndMechanism(
        urlRump: "imap://joe@example.com/INBOX/;uid=20/;section=1.2",
        mechanism: .internal
    )
}

extension ByteBuffer {
    fileprivate static let joeURLFetch = ByteBuffer(
        "imap://joe@example.com/INBOX/;uid=20/;section=1.2;urlauth=submit+fred:internal:91354a473744909de610943775f92038"
    )
}

extension SearchKey {
    fileprivate static let keysWithoutSequenceNumber: [SearchKey] = [
        .bcc("foo"),
        .uid(.set([1])),
        .answered,
        .subject("foo"),
        .or(.unseen, .uid(.set([1])))
    ]

    fileprivate static let keysWithSequenceNumber: [SearchKey] = [
        .sequenceNumbers(.set([1])),
        .or(.unseen, .sequenceNumbers(.set([1]))),
        .or(.uid(.set([1])), .sequenceNumbers(.set([1]))),
        .and([.unseen, .sequenceNumbers(.set([1]))]),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))])
    ]

    fileprivate static let keysWithoutUID: [SearchKey] = [
        .bcc("foo"),
        .sequenceNumbers(.set([1])),
        .answered,
        .subject("foo"),
        .or(.unseen, .sequenceNumbers(.set([1])))
    ]

    fileprivate static let keysWithUID: [SearchKey] = [
        .uid(.set([1])),
        .or(.unseen, .uid(.set([1]))),
        .or(.uid(.set([1])), .sequenceNumbers(.set([1]))),
        .and([.unseen, .uid(.set([1]))]),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))])
    ]

    fileprivate static let keysWithoutFlags: [SearchKey] = [
        .sequenceNumbers(.set([1])),
        .uid(.set([1])),
        .bcc("foo"),
        .uid(.set([1])),
        .subject("foo"),
        .or(.bcc("foo"), .uid(.set([1]))),
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))])
    ]

    fileprivate static let keysWithFlags: [SearchKey] = [
        .answered,
        .unanswered,
        .seen,
        .unseen,
        .keyword(Flag.Keyword("A")!),
        .unkeyword(Flag.Keyword("A")!),
        .flagged,
        .unflagged,
        .deleted,
        .undeleted,
        .draft,
        .undraft,
        .or(.answered, .uid(.set([1]))),
        .and([.answered, .sequenceNumbers(.set([1]))])
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
        .keyword(Flag.Keyword("A")!),
        .unkeyword(Flag.Keyword("A")!),
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
        .and([.uid(.set([1])), .sequenceNumbers(.set([1]))])
    ]
}

extension MessageIdentifierSetNonEmpty where IdentifierType == UID {
    fileprivate static var arbitrarySets: [Self] {
        [
            [100...200],
            [IdentifierType.min...IdentifierType.min],
            [43_195...43_195],
            .all
        ]
    }
}

extension PipeliningRequirement {
    fileprivate static let arbitraryRequirements: [PipeliningRequirement] = [
        .noMailboxCommandsRunning,
        .noUntaggedExpungeResponse,
        .noUIDBasedCommandRunning,
        .noFlagChanges(.all),
        .noFlagChanges([1]),
        .noFlagChanges([55...1000]),
        .noFlagReads(.all),
        .noFlagReads([1]),
        .noFlagReads([55...1000])
    ]
}

// MARK: -

private func expect(
    _ requirements: Set<PipeliningRequirement>,
    canStartWhileRunning behavior: Set<PipeliningBehavior>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(behavior.satisfies(requirements), sourceLocation: sourceLocation)
}

private func expect(
    _ requirements: Set<PipeliningRequirement>,
    canNotStartWhileRunning behavior: Set<PipeliningBehavior>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(!behavior.satisfies(requirements), sourceLocation: sourceLocation)
}

private func expect(
    commands: [(SourceLocation, Command)],
    doNotRequire requirement: PipeliningRequirement,
    _ message: @autoclosure () -> String = ""
) {
    commands.forEach { location, command in
        #expect(
            !command.pipeliningRequirements.contains(requirement),
            "Should not require \(requirement). \(message())",
            sourceLocation: location
        )
    }
}

private func expect(
    commands: [(SourceLocation, Command)],
    require requirement: PipeliningRequirement,
    _ message: @autoclosure () -> String = ""
) {
    commands.forEach { location, command in
        let r = command.pipeliningRequirements
        #expect(
            r.contains(requirement),
            "Should require \(requirement). Did: \(r). \(message())",
            sourceLocation: location
        )
    }
}

private func expect(
    commands: [(SourceLocation, Command)],
    doNotHaveBehavior behavior: PipeliningBehavior,
    _ message: @autoclosure () -> String = ""
) {
    commands.forEach { location, command in
        #expect(
            !command.pipeliningBehavior.contains(behavior),
            "Should not have \(behavior) behavior. \(message())",
            sourceLocation: location
        )
    }
}

private func expect(
    commands: [(SourceLocation, Command)],
    haveBehavior behavior: PipeliningBehavior,
    _ message: @autoclosure () -> String = ""
) {
    commands.forEach { location, command in
        #expect(
            command.pipeliningBehavior.contains(behavior),
            "Should have \(behavior) behavior. \(message())",
            sourceLocation: location
        )
    }
}

// MARK: -

@Suite("Pipelining")
struct PipeliningTests {
    // MARK: Interaction of Requirements and Behavior

    @Test("can start with empty behavior")
    func canStartWithEmptyBehavior() {
        // When the running command doesn't have any requirements, anything can run:
        expect(
            [],
            canStartWhileRunning: []
        )
        expect(
            [.noMailboxCommandsRunning],
            canStartWhileRunning: []
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: []
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: []
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: []
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: []
        )
        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canStartWhileRunning: []
        )
    }

    @Test("can start with changes mailbox selection behavior")
    func canStartWithChangesMailboxSelectionBehavior() {
        expect(
            [],
            canStartWhileRunning: [.changesMailboxSelection]
        )
        // Don't start a command that depends on the selected state
        // while changing the selected state.
        expect(
            [.noMailboxCommandsRunning],
            canNotStartWhileRunning: [.changesMailboxSelection]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: [.changesMailboxSelection]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: [.changesMailboxSelection]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: [.changesMailboxSelection]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: [.changesMailboxSelection]
        )

        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.changesMailboxSelection]
        )
    }

    @Test("can start with depends on mailbox selection behavior")
    func canStartWithDependsOnMailboxSelectionBehavior() {
        expect(
            [],
            canStartWhileRunning: [.dependsOnMailboxSelection]
        )
        // Don't start a command that requires no mailbox-specific commands,
        // while mailbox-specific commands are running. E.g. don't change the
        // mailbox while running a FETCH.
        expect(
            [.noMailboxCommandsRunning],
            canNotStartWhileRunning: [.dependsOnMailboxSelection]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: [.dependsOnMailboxSelection]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: [.dependsOnMailboxSelection]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: [.dependsOnMailboxSelection]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: [.dependsOnMailboxSelection]
        )

        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.dependsOnMailboxSelection]
        )
    }

    @Test("can start with may trigger untagged expunge behavior")
    func canStartWithMayTriggerUntaggedExpungeBehavior() {
        expect(
            [],
            canStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
        expect(
            [.noMailboxCommandsRunning],
            canStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
        // If a command may trigger "untagged EXPUNGE", don't start a command
        // that requires this not to happen.
        expect(
            [.noUntaggedExpungeResponse],
            canNotStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )

        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.mayTriggerUntaggedExpunge]
        )
    }

    @Test("can start with is UID based behavior")
    func canStartWithIsUidBasedBehavior() {
        expect(
            [],
            canStartWhileRunning: [.isUIDBased]
        )
        expect(
            [.noMailboxCommandsRunning],
            canStartWhileRunning: [.isUIDBased]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: [.isUIDBased]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canNotStartWhileRunning: [.isUIDBased]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: [.isUIDBased]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: [.isUIDBased]
        )
        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.isUIDBased]
        )
    }

    @Test("can start with changes flags behavior")
    func canStartWithChangesFlagsBehavior() {
        expect(
            [],
            canStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            [.noMailboxCommandsRunning],
            canStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canNotStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canStartWhileRunning: [.changesFlagsOnAnyMessage]
        )
        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.changesFlagsOnAnyMessage]
        )

        expect(
            [.noFlagChanges([200...300])],
            canStartWhileRunning: [.changesFlags([1...100]), .changesFlags([400...500])]
        )
        expect(
            [.noFlagChanges([200...300])],
            canNotStartWhileRunning: [.changesFlags([100...200])]
        )
        expect(
            [.noFlagChanges([200...300])],
            canStartWhileRunning: [.readsFlags([100...200])]
        )
    }

    @Test("can start with reads flags behavior")
    func canStartWithReadsFlagsBehavior() {
        expect(
            [],
            canStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            [.noMailboxCommandsRunning],
            canStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canNotStartWhileRunning: [.readsFlagsFromAnyMessage]
        )
        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.readsFlagsFromAnyMessage]
        )

        expect(
            [.noFlagReads([200...300])],
            canStartWhileRunning: [.readsFlags([1...100]), .readsFlags([400...500])]
        )
        expect(
            [.noFlagReads([200...300])],
            canNotStartWhileRunning: [.readsFlags([100...200])]
        )
        expect(
            [.noFlagReads([200...300])],
            canStartWhileRunning: [.changesFlags([100...200])]
        )
    }

    @Test("can start with barrier behavior")
    func canStartWithBarrierBehavior() {
        // Nothing can be started, while a barrier is running.
        expect(
            [],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            [.noMailboxCommandsRunning],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            [.noUntaggedExpungeResponse],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            [.noUIDBasedCommandRunning],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            [.noFlagChangesToAnyMessage],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            [.noFlagReadsFromAnyMessage],
            canNotStartWhileRunning: [.barrier]
        )
        expect(
            Set(PipeliningRequirement.arbitraryRequirements),
            canNotStartWhileRunning: [.barrier]
        )
    }

    // MARK: Command Requirements

    @Test("append")
    func append() {
        let append = CommandStreamPart.append(.start(tag: "A1", appendingTo: .food))
        #expect(append.pipeliningRequirements == [])
        #expect(
            append.pipeliningBehavior == [
                .mayTriggerUntaggedExpunge
            ]
        )
    }

    @Test("catenate part")
    func catenatePart() {
        // CATENATE may reference other messages by UID:
        let append = CommandStreamPart.append(.catenateURL(.joeURLFetch))
        #expect(append.pipeliningRequirements == [])
        #expect(
            append.pipeliningBehavior == [
                .isUIDBased
            ]
        )
    }

    @Test("UID batches")
    func uidBatches() {
        let append = CommandStreamPart.tagged(.init(tag: "A1", command: .uidBatches(batchSize: 1_000)))
        #expect(append.pipeliningRequirements == [])
        #expect(
            append.pipeliningBehavior == [
                .isUIDBased,
                .mayTriggerUntaggedExpunge
            ]
        )
    }

    @Test("command requires no mailbox commands running")
    func commandRequiresNoMailboxCommandsRunning() {
        // Which commands have the requirements that:
        // > No command that depend on the _Selected State_ must be running.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),

                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),

                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),

                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),

                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),

                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            doNotRequire: .noMailboxCommandsRunning
        )

        expect(
            commands: [
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .close)
            ],
            require: .noMailboxCommandsRunning
        )
    }

    @Test("command requires no untagged expunge response")
    func commandRequiresNoUntaggedExpungeResponse() {
        // Which commands have the requirements that:
        // > No command besides `FETCH`, `STORE`, and `SEARCH` is running.
        // This is a requirement for all sequence number based commands.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),

                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .check),
                (#_sourceLocation, .close),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food))
            ],
            doNotRequire: .noUntaggedExpungeResponse
        )

        // All commands that reference messages by sequence numbers have this requirement:
        expect(
            commands: [
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))))
            ],
            require: .noUntaggedExpungeResponse
        )

        // SEARCH, ESEARCH, and UID SEARCH
        // only have this requirement if a search key references sequence numbers.
        SearchKey.keysWithoutSequenceNumber.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                doNotRequire: .noUntaggedExpungeResponse,
                "key: \(key)"
            )
        }
        SearchKey.keysWithSequenceNumber.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                require: .noUntaggedExpungeResponse,
                "key: \(key)"
            )
        }
    }

    @Test("command requires no UID based command running")
    func commandRequiresNoUidBasedCommandRunning() {
        // Which commands have the requirements that:
        // > No command is running that uses UIDs to specify messages.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),

                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .check),
                (#_sourceLocation, .close),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .bcc("foo")))),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .uid(.set([1]))))),
                (#_sourceLocation, .search(key: .bcc("foo"), charset: nil, returnOptions: [])),
                (#_sourceLocation, .search(key: .uid(.set([1])), charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidSearch(key: .bcc("foo"), charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidSearch(key: .uid(.set([1])), charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food))
            ],
            doNotRequire: .noUIDBasedCommandRunning
        )

        // All commands that reference messages by sequence numbers have this requirement:
        expect(
            commands: [
                (#_sourceLocation, .uidSearch(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [])),
                (#_sourceLocation, .search(key: .sequenceNumbers(.set([1])), charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .sequenceNumbers(.set([1]))))),

                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))))
            ],
            require: .noUIDBasedCommandRunning
        )

        // SEARCH, ESEARCH, and UID SEARCH
        // only have this requirement if a search key references sequence numbers.
        SearchKey.keysWithoutSequenceNumber.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                doNotRequire: .noUIDBasedCommandRunning,
                "key: \(key)"
            )
        }
        SearchKey.keysWithSequenceNumber.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                require: .noUIDBasedCommandRunning,
                "key: \(key)"
            )
        }
    }

    @Test("command requires no flag changes")
    func commandRequiresNoFlagChanges() {
        // Which commands have the requirements that:
        // > No STORE command is running.
        // (i.e. no flags are being changed)

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),

                (#_sourceLocation, .logout),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .check),
                (#_sourceLocation, .close),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                // STORE is ok if SILENT is set:
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered]))))
            ],
            doNotRequire: .noFlagChangesToAnyMessage
        )

        expect(
            commands: [
                // FETCH that return flags:
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid, .flags], [])),
                (#_sourceLocation, .fetch(.set([1]), [.uid, .flags], [])),
                (#_sourceLocation, .uidFetch(.lastCommand, [.envelope, .uid, .flags], [])),
                // STORE without SILENT will also return flags:
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))))
            ],
            require: .noFlagChangesToAnyMessage
        )

        MessageIdentifierSetNonEmpty<UID>.arbitrarySets.forEach { uids in
            expect(
                commands: [
                    // UID FETCH that return flags:
                    (#_sourceLocation, .uidFetch(.set(uids), [.envelope, .uid, .flags], [])),
                    (#_sourceLocation, .uidFetch(.set(uids), [.uid, .flags], [])),
                    // UID STORE without SILENT will also return flags:
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: false, list: [.answered]))))
                ],
                require: .noFlagChanges(uids),
                "uids: \(uids)"
            )
        }

        // SEARCH, ESEARCH, and UID SEARCH have this requirement only if they
        // reference flags:
        SearchKey.keysWithoutFlags.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                doNotRequire: .noFlagChangesToAnyMessage,
                "key: \(key)"
            )
        }
        SearchKey.keysWithFlags.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                require: .noFlagChangesToAnyMessage,
                "key: \(key)"
            )
        }
    }

    @Test("command requires no flag reads")
    func commandRequiresNoFlagReads() {
        // Which commands have the requirements that:
        /// > No command is running that retrieves flags.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),

                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .check),
                (#_sourceLocation, .close),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid, .flags], [])),
                (#_sourceLocation, .fetch(.set([1]), [.uid, .flags], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid, .flags], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.uid, .flags], [])),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food))
            ],
            doNotRequire: .noFlagReadsFromAnyMessage
        )

        // STORE / UID STORE are the only ones with this requirement:
        expect(
            commands: [
                (#_sourceLocation, .uidStore(.lastCommand, [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))))
            ],
            require: .noFlagReadsFromAnyMessage
        )
        MessageIdentifierSetNonEmpty<UID>.arbitrarySets.forEach { uids in
            expect(
                commands: [
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: false, list: [.answered])))),
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: true, list: [.answered]))))
                ],
                require: .noFlagReads(uids),
                "uids: \(uids)"
            )
        }

        // SEARCH, ESEARCH, and UID SEARCH never have this requirement.
        SearchKey.arbitraryKeys.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                doNotRequire: .noFlagReadsFromAnyMessage,
                "key: \(key)"
            )
        }
    }

    // MARK: Command Behavior

    @Test("command behavior changes mailbox selection")
    func commandBehaviorChangesMailboxSelection() {
        /// Commands that change the _mailbox selection_.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),

                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food))
            ],
            doNotHaveBehavior: .changesMailboxSelection
        )

        expect(
            commands: [
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .close)
            ],
            haveBehavior: .changesMailboxSelection
        )
    }

    @Test("command behavior depends on mailbox selection")
    func commandBehaviorDependsOnMailboxSelection() {
        /// Commands that depend on the _mailbox selection_.

        expect(
            commands: [
                (#_sourceLocation, .capability),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .status(.food, [.messageCount])),

                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),

                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),

                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),

                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            doNotHaveBehavior: .dependsOnMailboxSelection
        )

        expect(
            commands: [
                (#_sourceLocation, .noop),
                (#_sourceLocation, .check),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .idleStart)
            ],
            haveBehavior: .dependsOnMailboxSelection
        )
    }

    @Test("command behavior may trigger untagged expunge")
    func commandBehaviorMayTriggerUntaggedExpunge() {
        // All commands, except for FETCH, STORE, and SEARCH can
        // trigger an untagged EXPUNGE.
        expect(
            commands: [
                // FETCH, STORE, and SEARCH
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .search(key: .answered, charset: nil, returnOptions: [.all])),
                // Does not make sense for these:
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .logout)
            ],
            doNotHaveBehavior: .mayTriggerUntaggedExpunge
        )

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),

                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),

                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            haveBehavior: .mayTriggerUntaggedExpunge
        )
    }

    @Test("command behavior is UID based")
    func commandBehaviorIsUidBased() {
        /// Commands that use UIDs to specify messages.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .idleStart),

                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),

                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),

                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil]))
            ],
            doNotHaveBehavior: .isUIDBased
        )

        expect(
            commands: [
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                // `GENURLAUTH` and `URLFETCH` (indirectly) reference UIDs:
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            haveBehavior: .isUIDBased
        )

        SearchKey.keysWithoutUID.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: []))
                ],
                doNotHaveBehavior: .isUIDBased,
                "key: \(key)"
            )
            // UID SEARCH has this behavior even if the key does not
            // reference UIDs:
            expect(
                commands: [
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key)))
                ],
                haveBehavior: .isUIDBased,
                "key: \(key)"
            )
        }
        SearchKey.keysWithUID.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                haveBehavior: .isUIDBased,
                "key: \(key)"
            )
        }
    }

    @Test("command behavior changes flags")
    func commandBehaviorChangesFlags() {
        /// Commands that change flags on messages.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .idleStart),

                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),

                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            doNotHaveBehavior: .changesFlagsOnAnyMessage
        )

        expect(
            commands: [
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .uidStore(.lastCommand, [], .flags(.add(silent: true, list: [.answered]))))
            ],
            haveBehavior: .changesFlagsOnAnyMessage
        )
        MessageIdentifierSetNonEmpty<UID>.arbitrarySets.forEach { uids in
            expect(
                commands: [
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: true, list: [.answered])))),
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: false, list: [.answered]))))
                ],
                haveBehavior: .changesFlags(uids)
            )
        }
    }

    @Test("command behavior reads flags")
    func commandBehaviorReadsFlags() {
        /// Command that are querying / reading flags.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .login(username: "user", password: "password")),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),
                (#_sourceLocation, .idleStart),
                (#_sourceLocation, .enable([.condStore])),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch])),

                // STORE is ok as long as it is SILENT
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),

                // FETCH is ok as long as it's not fetching flags:
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], []))
            ],
            doNotHaveBehavior: .readsFlagsFromAnyMessage
        )

        expect(
            commands: [
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid, .flags], [])),
                (#_sourceLocation, .fetch(.set([1]), [.uid, .flags], [])),
                // This will also return flags:
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .uidStore(.lastCommand, [], .flags(.add(silent: false, list: [.answered]))))
            ],
            haveBehavior: .readsFlagsFromAnyMessage
        )
        MessageIdentifierSetNonEmpty<UID>.arbitrarySets.forEach { uids in
            expect(
                commands: [
                    (#_sourceLocation, .uidFetch(.set(uids), [.envelope, .uid, .flags], [])),
                    (#_sourceLocation, .uidFetch(.set(uids), [.uid, .flags], [])),
                    // This will also return flags:
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: false, list: [.answered])))),
                    (#_sourceLocation, .uidStore(.set(uids), [], .flags(.add(silent: false, list: [.answered]))))
                ],
                haveBehavior: .readsFlags(uids)
            )
        }

        // SEARCH, ESEARCH, and UID SEARCH have this behavior only if they
        // reference flags:
        SearchKey.keysWithoutFlags.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                doNotHaveBehavior: .readsFlagsFromAnyMessage,
                "key: \(key)"
            )
        }
        SearchKey.keysWithFlags.forEach { key in
            expect(
                commands: [
                    (#_sourceLocation, .search(key: key, charset: nil, returnOptions: [])),
                    (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: key))),
                    (#_sourceLocation, .uidSearch(key: key, charset: nil, returnOptions: []))
                ],
                haveBehavior: .readsFlagsFromAnyMessage,
                "key: \(key)"
            )
        }
    }

    @Test("command behavior barrier")
    func commandBehaviorBarrier() {
        /// No additional commands may be sent until these commands complete.

        expect(
            commands: [
                (#_sourceLocation, .capability),
                (#_sourceLocation, .noop),

                (#_sourceLocation, .login(username: "user", password: "password")),

                (#_sourceLocation, .delete(.food)),
                (#_sourceLocation, .rename(from: .food, to: .food, parameters: [:])),
                (#_sourceLocation, .examine(.food)),
                (#_sourceLocation, .create(.food, [])),
                (#_sourceLocation, .list(nil, reference: .food, .food, [])),
                (#_sourceLocation, .listIndependent([], reference: .food, .food, [])),
                (#_sourceLocation, .lsub(reference: .food, pattern: "Food")),
                (#_sourceLocation, .unsubscribe(.food)),
                (#_sourceLocation, .subscribe(.food)),
                (#_sourceLocation, .status(.food, [.messageCount])),
                (#_sourceLocation, .close),
                (#_sourceLocation, .select(.food)),
                (#_sourceLocation, .unselect),
                (#_sourceLocation, .enable([.condStore])),
                (#_sourceLocation, .id([:])),
                (#_sourceLocation, .namespace),

                (#_sourceLocation, .check),
                (#_sourceLocation, .expunge),
                (#_sourceLocation, .fetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .fetch(.set([1]), [.bodyStructure(extensions: false)], [])),
                (#_sourceLocation, .uidSearch(key: .all, charset: nil, returnOptions: [])),
                (#_sourceLocation, .uidFetch(.set([1]), [.envelope, .uid], [])),
                (#_sourceLocation, .uidCopy(.set([1]), .food)),
                (#_sourceLocation, .uidMove(.set([1]), .food)),
                (#_sourceLocation, .uidStore(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .copy(.set([1]), .food)),
                (#_sourceLocation, .move(.set([1]), .food)),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: true, list: [.answered])))),
                (#_sourceLocation, .store(.set([1]), [], .flags(.add(silent: false, list: [.answered])))),
                (#_sourceLocation, .search(key: .all, charset: nil, returnOptions: [.all])),
                (#_sourceLocation, .uidExpunge(.set([1]))),
                (#_sourceLocation, .getQuota(QuotaRoot("foo"))),
                (#_sourceLocation, .getQuotaRoot(.food)),
                (#_sourceLocation, .setQuota(QuotaRoot("foo"), [])),
                (#_sourceLocation, .getMetadata(options: [], mailbox: .food, entries: ["/shared/comment"])),
                (#_sourceLocation, .setMetadata(mailbox: .food, entries: ["/shared/comment": nil])),
                (#_sourceLocation, .extendedSearch(ExtendedSearchOptions(key: .all))),
                (#_sourceLocation, .resetKey(mailbox: nil, mechanisms: [.internal])),
                (#_sourceLocation, .generateAuthorizedURL([.joe])),
                (#_sourceLocation, .urlFetch([.joeURLFetch]))
            ],
            doNotHaveBehavior: .barrier
        )

        expect(
            commands: [
                (#_sourceLocation, .startTLS),
                (#_sourceLocation, .authenticate(mechanism: .plain, initialResponse: nil)),
                (#_sourceLocation, .compress(.deflate)),
                (#_sourceLocation, .logout),
                (#_sourceLocation, .idleStart)
            ],
            haveBehavior: .barrier
        )
    }
}
