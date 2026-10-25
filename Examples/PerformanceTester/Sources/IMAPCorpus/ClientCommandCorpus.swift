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

/// The commands a client sends in volume, **as wire text**.
///
/// This is a second command corpus, and it exists for one reason: ``CommandCorpus`` is written as
/// model values, and every model value that carries bytes is spelled differently before and after the
/// buffer migration — `MailboxName(Array("x".utf8))` against `MailboxName(ByteBuffer(string: "x"))`.
/// A corpus of *text* names nothing the migration touched, so the same definition feeds a library
/// built either way, and the `IMAPDispatchClient` before/after comparison is fed byte-identical input
/// in both configurations. The model values its encode cases need come from parsing this text with
/// whichever parser is being measured.
///
/// The list mirrors ``CommandCorpus/hot`` — what a real client sends in volume, weighted towards
/// `UID FETCH`, which is where a client spends its protocol budget. It is deliberately *not* derived
/// from that corpus by encoding it: that would make the bytes depend on the encoder under
/// measurement, and the two configurations would no longer be comparing like with like.
public enum ClientCommandCorpus {
    /// Every command, tagged, one per line, in the order a session sends them.
    ///
    /// Tags are short on purpose: they are one or two bytes of every command and are not what is being
    /// measured.
    public static let lines: [(name: String, text: String)] = [
        // Connect and authenticate.
        ("capability", "a1 CAPABILITY"),
        ("starttls", "a2 STARTTLS"),
        ("login", "a3 LOGIN \"benchmark-user\" \"benchmark-password\""),
        (
            "authenticate_xoauth2",
            "a4 AUTHENTICATE XOAUTH2 dXNlcj1iZW5jaG1hcmstdXNlcgFhdXRoPUJlYXJlciB5YTI5LnRva2VuAQE="
        ),
        ("id", "a5 ID (\"name\" \"benchmark-client\" \"version\" \"1.0\")"),
        ("enable_condstore_qresync", "a6 ENABLE CONDSTORE QRESYNC"),
        ("namespace", "a7 NAMESPACE"),

        // Discover the mailbox tree. A client does this on every connect.
        ("list_all", "a8 LIST \"\" \"*\""),
        ("list_subscribed", "a9 LIST (SUBSCRIBED) \"\" \"*\""),
        (
            "list_return_status",
            "b1 LIST \"\" \"*\" RETURN (STATUS (MESSAGES UNSEEN UIDNEXT UIDVALIDITY))"
        ),
        ("lsub", "b2 LSUB \"\" \"*\""),
        ("status", "b3 STATUS INBOX (MESSAGES RECENT UIDNEXT UIDVALIDITY UNSEEN HIGHESTMODSEQ)"),

        // Open a mailbox.
        ("select", "b4 SELECT INBOX"),
        ("examine_condstore", "b5 EXAMINE INBOX (CONDSTORE)"),

        // Sync. This is the bulk of a client's traffic.
        ("uid_fetch_all_flags", "b6 UID FETCH 1:* (FLAGS)"),
        ("uid_fetch_flags_changedsince", "b7 UID FETCH 1:* (FLAGS UID MODSEQ) (CHANGEDSINCE 987654)"),
        (
            "uid_fetch_message_list",
            "b8 UID FETCH 1:100 (UID RFC822.SIZE INTERNALDATE ENVELOPE BODYSTRUCTURE)"
        ),
        (
            "uid_fetch_header_fields",
            "b9 UID FETCH 1:100 (BODY.PEEK[HEADER.FIELDS (DATE FROM TO CC SUBJECT MESSAGE-ID "
                + "IN-REPLY-TO REFERENCES LIST-ID X-PRIORITY)])"
        ),
        ("uid_fetch_body_text", "c1 UID FETCH 12345 (BODY.PEEK[TEXT])"),
        ("uid_search_unseen", "c2 UID SEARCH UNSEEN"),
        ("uid_store_seen", "c3 UID STORE 1:100 +FLAGS (\\Seen)"),
        ("uid_copy", "c4 UID COPY 1:100 \"Archive/2024\""),
        ("uid_move", "c5 UID MOVE 1:100 \"Archive/2024\""),
        ("uid_expunge", "c6 UID EXPUNGE 1:100"),

        // Keep-alive and teardown.
        ("noop", "c7 NOOP"),
        ("check", "c8 CHECK"),
        ("close", "c9 CLOSE"),
        ("logout", "d1 LOGOUT"),
    ]
}
