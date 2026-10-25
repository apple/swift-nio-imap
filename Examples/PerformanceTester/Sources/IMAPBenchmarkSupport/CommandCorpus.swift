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
import NIOIMAP

/// The client commands the benchmarks encode and parse, split by how much traffic each shape
/// actually carries.
///
/// ## How this corpus was chosen
///
/// It started as the list from the hand-rolled `NIOIMAPPerformanceTester` that preceded these
/// benchmarks, which was assembled for breadth rather than for realism. Audited against what a mail
/// client actually sends, that list had three problems:
///
/// - **No UID commands at all.** `uidFetch`, `uidStore`, `uidCopy`, `uidMove`, `uidSearch` and
///   `uidExpunge` were all absent, and a real client sends almost nothing else once a mailbox is
///   selected — sequence numbers shift under it, UIDs do not.
/// - **`LIST`, `STATUS`, `SEARCH` and every `BODY[…]` fetch were missing**, while `QUOTA` had four
///   entries, `GENURLAUTH` two and `SETMETADATA`/`GETMETADATA` one each. The corpus was weighted
///   towards the extensions a client sends never or once per session, and away from the four
///   commands it sends thousands of times.
/// - **One entry was a duplicate.** `move_last command` and `move_all` were both
///   `.move(.lastCommand, .inbox)`; the second was presumably meant to be `.set(.all)`.
///
/// ## The split
///
/// ``hot`` is what a client sends in volume, so it gets a benchmark per case: a regression in `UID
/// FETCH` matters in a way that a regression in `SETQUOTA` does not. ``coverage`` is breadth over
/// the rest of the grammar, measured only in aggregate. ``all`` is both, and is what the
/// whole-corpus benchmarks use.
public enum CommandCorpus {
    /// A mailbox name that needs no quoting or literal.
    private static let plainMailbox = MailboxName(Array("Archive/2024".utf8))

    /// The header fields a client asks for when building a message list.
    private static let headerFields = [
        "DATE", "FROM", "TO", "CC", "SUBJECT", "MESSAGE-ID", "IN-REPLY-TO", "REFERENCES",
        "LIST-ID", "X-PRIORITY",
    ]

    /// Commands a client sends in volume, in roughly the order a session sends them.
    ///
    /// Each of these gets its own benchmark. The weighting is deliberate: seven of the twelve
    /// mailbox-open-and-sync commands are `UID FETCH` variants, because that is where a real client
    /// spends its protocol budget.
    public static let hot: [(name: String, command: Command)] = [
        // Connect and authenticate.
        ("capability", .capability),
        ("starttls", .startTLS),
        ("login", .login(username: "benchmark-user", password: "benchmark-password")),
        (
            "authenticate_xoauth2",
            .authenticate(
                mechanism: .init("XOAUTH2")!,
                initialResponse: .init(
                    Array("dXNlcj1iZW5jaG1hcmstdXNlcgFhdXRoPUJlYXJlciB5YTI5LnRva2VuAQE=".utf8)
                )
            )
        ),
        ("id", .id(["name": "benchmark-client", "version": "1.0"])),
        ("enable_condstore_qresync", .enable([.condStore, .qresync])),
        ("namespace", .namespace),

        // Discover the mailbox tree. A client does this on every connect.
        ("list_all", .list(nil, reference: MailboxName([]), .mailbox(Array("*".utf8)), [])),
        (
            "list_special_use",
            .list(
                nil,
                reference: MailboxName([]),
                .mailbox(Array("*".utf8)),
                [.specialUse, .subscribed, .children]
            )
        ),
        (
            "list_return_status",
            .list(
                nil,
                reference: MailboxName([]),
                .mailbox(Array("*".utf8)),
                [.statusOption([.messageCount, .unseenCount, .uidNext, .uidValidity])]
            )
        ),
        ("lsub", .lsub(reference: MailboxName([]), pattern: Array("*".utf8))),
        (
            "status",
            .status(
                .inbox,
                [.messageCount, .recentCount, .uidNext, .uidValidity, .unseenCount, .highestModificationSequence]
            )
        ),

        // Open a mailbox.
        ("select", .select(.inbox, [])),
        (
            "select_qresync",
            .select(
                .inbox,
                [
                    .qresync(
                        .init(
                            uidValidity: 1_437_559_275,
                            modificationSequenceValue: .init(integerLiteral: 987_654),
                            knownUIDs: [1...3, 5...7, 10...1000],
                            sequenceMatchData: .init(
                                knownSequenceSet: .set([1...10, 10...20, 30...100]),
                                knownUidSet: .set([100...200, 300...400])
                            )
                        )
                    )
                ]
            )
        ),
        ("examine", .examine(.inbox, [.condStore])),

        // Sync. This is the bulk of a client's traffic.
        ("uid_fetch_all_flags", .uidFetch(.set(.all), [.flags], [])),
        (
            "uid_fetch_flags_changedsince",
            .uidFetch(
                .set(.all),
                [.flags, .uid, .modificationSequence],
                [.changedSince(.init(modificationSequence: .init(integerLiteral: 987_654)))]
            )
        ),
        (
            "uid_fetch_headers",
            .uidFetch(
                .set([1...500]),
                [.uid, .rfc822Size, .internalDate, .flags, .envelope, .bodyStructure(extensions: false)],
                []
            )
        ),
        (
            "uid_fetch_header_fields",
            .uidFetch(
                .set([1...100]),
                [.bodySection(peek: true, .init(kind: .headerFields(headerFields)), nil)],
                []
            )
        ),
        (
            "uid_fetch_body_partial",
            .uidFetch(.set([12345...12345]), [.bodySection(peek: true, .init(), 0...10_239)], [])
        ),
        (
            "uid_fetch_body_text",
            .uidFetch(.set([12345...12345]), [.bodySection(peek: true, .init(part: [1], kind: .text), nil)], [])
        ),
        (
            "uid_fetch_set_fragmented",
            // What a client sends after a partial sync: a set with many disjoint ranges.
            .uidFetch(
                .set([1...2, 5...9, 14...14, 20...45, 100...220, 3000...4000, 9000...9001]),
                [.uid, .flags],
                []
            )
        ),

        // Mutate.
        (
            "uid_store_add_seen",
            .uidStore(.set([1...50]), [], .flags(.add(silent: true, list: [.seen])))
        ),
        (
            "uid_store_remove_flags_unchangedsince",
            .uidStore(
                .set([1...50]),
                [.unchangedSince(.init(modificationSequence: .init(integerLiteral: 987_654)))],
                .flags(.remove(silent: false, list: [.flagged, .draft]))
            )
        ),
        ("uid_copy", .uidCopy(.set([1...50]), plainMailbox)),
        ("uid_move", .uidMove(.set([1...50]), plainMailbox)),
        ("uid_expunge", .uidExpunge(.set([1...50]))),

        // Search.
        ("uid_search_unseen", .uidSearch(key: .unseen)),
        (
            "uid_search_compound",
            .uidSearch(
                key: .and([
                    .not(.deleted),
                    .since(IMAPCalendarDay(year: 2024, month: 1, day: 1)!),
                    .or(.from(Array("sender@example.com".utf8)), .subject(Array("invoice".utf8))),
                    .messageSizeLarger(4_096),
                ]),
                charset: "UTF-8",
                returnOptions: [.all, .count]
            )
        ),

        // Idle, poll, and close down.
        ("idle_start", .idleStart),
        ("noop", .noop),
        ("check", .check),
        ("expunge", .expunge),
        ("close", .close),
        ("unselect", .unselect),
        ("logout", .logout),
    ]

    /// Breadth over the rest of the grammar: extensions, administrative commands, and the
    /// sequence-number twins of the UID commands above.
    ///
    /// Measured only in aggregate, via the whole-corpus benchmarks. A client sends these never, once
    /// per session, or only when a user does something unusual.
    public static let coverage: [(name: String, command: Command)] = [
        // Sequence-number forms. Still valid, still parsed, rarely sent by a modern client.
        ("fetch_seq_lots", .fetch(.set(.all), [.envelope, .flags, .internalDate, .uid], [])),
        ("fetch_last_command", .fetch(.lastCommand, [.envelope, .flags], [])),
        ("store_seq", .store(.set([1...10]), [], .flags(.add(silent: false, list: [.answered])))),
        ("copy_seq", .copy(.set([1...2, 4...5, 10...20]), .inbox)),
        ("move_seq", .move(.set([1...100, 200...300, 3000...4000]), .inbox)),
        ("search_seq", .search(key: .all)),

        // Mailbox management.
        ("create", .create(MailboxName(Array("My Test Mailbox".utf8)), [])),
        (
            "create_special_use",
            .create(MailboxName(Array("My Test Mailbox".utf8)), [.attributes([.archive])])
        ),
        (
            "create_many_att",
            .create(
                MailboxName(Array("My Test Mailbox".utf8)),
                [.attributes([.flagged, .junk, .archive, .sent, .trash])]
            )
        ),
        ("delete", .delete(.inbox)),
        ("rename", .rename(from: .inbox, to: MailboxName(Array("not an inbox".utf8)), parameters: [:])),
        (
            "rename_params",
            .rename(
                from: .inbox,
                to: MailboxName(Array("not an inbox".utf8)),
                parameters: ["name1": nil, "name2": .sequence(.set([1...2, 3...4]))]
            )
        ),
        ("subscribe", .subscribe(.inbox)),
        ("unsubscribe", .unsubscribe(.inbox)),
        (
            "examine_lots_param",
            .examine(
                .inbox,
                [
                    .basic(.init(key: "param1", value: nil)), .basic(.init(key: "param2", value: nil)),
                    .basic(.init(key: "param3", value: .sequence(.set([1...5, 10...100])))),
                    .basic(.init(key: "param4", value: .comp(["str1"]))),
                ]
            )
        ),

        // ESEARCH / SORT.
        ("esearch_all", .extendedSearch(.init(key: .all))),
        (
            "esearch_complex",
            .extendedSearch(
                .init(
                    key: .and([.younger(123), .or(.keyword(.colorBit0), .keyword(.colorBit1))]),
                    charset: "UTF-8",
                    returnOptions: [.min, .max, .count],
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])!
                )
            )
        ),
        ("uid_sort", .uidSort(criteria: [.date, .descending(.subject)], charset: "UTF-8", key: .unseen)),
        ("uid_batches", .uidBatches(batchSize: 100, batchRange: 1...10_000)),

        // Extensions a client touches once, or not at all.
        ("enable_lots", .enable([.acl, .binary, .catenate, .condStore, .children, .extendedSearch, .esort])),
        ("auth_plain_nil", .authenticate(mechanism: .plain, initialResponse: nil)),
        ("auth_plain_empty", .authenticate(mechanism: .plain, initialResponse: .empty)),
        ("compress_deflate", .compress(.deflate)),
        ("get_jmap_access", .getJMAPAccess),
        ("getquota", .getQuota(QuotaRoot("inbox"))),
        ("getquotaroot", .getQuotaRoot(.inbox)),
        (
            "setquota",
            .setQuota(
                QuotaRoot("inbox"),
                [
                    .init(resourceName: "size", limit: 100), .init(resourceName: "messages", limit: 100),
                    .init(resourceName: "disk", limit: 100),
                ]
            )
        ),
        (
            "getmetadata",
            .getMetadata(options: [.maxSize(123), .scope(.infinity)], mailbox: .inbox, entries: ["test1", "test2"])
        ),
        ("setmetadata", .setMetadata(mailbox: .inbox, entries: ["/private/comment": .init(Array("hi".utf8))])),
        (
            "genurlauth",
            .generateAuthorizedURL([
                .init(urlRump: Array("test1".utf8), mechanism: .internal),
                .init(urlRump: Array("test2".utf8), mechanism: .internal),
            ])
        ),
        ("resetkey", .resetKey(.mailbox(.inbox, mechanisms: [.internal]))),
        ("urlfetch", .urlFetch([Array("imap://example.com/INBOX;UID=1".utf8)])),
    ]

    /// Every command in the corpus: ``hot`` followed by ``coverage``.
    public static let all: [(name: String, command: Command)] = hot + coverage
}
