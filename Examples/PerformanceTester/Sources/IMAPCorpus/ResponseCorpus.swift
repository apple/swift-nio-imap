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

import NIO

/// The server responses the benchmarks parse and encode.
///
/// Every corpus here is defined **as wire bytes**, and the model values the encode benchmarks use
/// are obtained by parsing those bytes once at registration time
/// (`DispatchClient.responses(parsing:)`). One definition, so the two sides cannot drift apart, and no
/// hand-built `BodyStructure` literal to keep in sync with the text it is supposed to represent.
///
/// Three shapes, because server traffic is not one thing:
///
/// - ``sessionBytes()`` — everything a client sees that is *not* a message: capabilities, the mailbox
///   tree, `STATUS`, the `SELECT` preamble, search results, unsolicited flag updates and expunges,
///   tagged completions. Individually small, collectively most of the distinct grammar a client
///   parses, and a shape the old corpus covered not at all.
/// - ``bodyStructureBytes(messageCount:)`` — the heavy FETCH: `ENVELOPE` plus a nested
///   `BODYSTRUCTURE`. This is the most expensive thing a client parses per message and the most
///   deeply recursive part of the grammar.
/// - ``sweepBytes(messageCount:)`` — the light FETCH: UID, size, flags. What a flag sync looks like.
public enum ResponseCorpus {
    /// The default number of messages in a sweep.
    ///
    /// One message contributes several responses (a start, one per attribute, a finish), so this is
    /// a thousand *messages*, not a thousand responses.
    public static let defaultMessageCount = 1_000

    // MARK: - Envelopes and body structures

    /// An envelope as it appears on the wire: ten fields, six of them address lists.
    private static func envelope(subject: String) -> String {
        """
        ENVELOPE ("Wed, 17 Jul 2024 09:14:22 +0200" "\(subject)" \
        (("Alice Example" NIL "alice" "example.com")) \
        (("Alice Example" NIL "alice" "example.com")) \
        (("Alice Example" NIL "alice" "example.com")) \
        (("Bob Example" NIL "bob" "example.org") ("Carol Example" NIL "carol" "example.net")) \
        (("Dave Example" NIL "dave" "example.com")) NIL \
        "<parent.message.1721200461@example.com>" "<abc123.def456.1721200462@example.com>")
        """
    }

    /// A body structure as it appears on the wire, for a reply that carries an attachment and a
    /// forwarded message.
    ///
    /// ```
    /// multipart/mixed
    ///   multipart/alternative
    ///     text/plain
    ///     text/html
    ///   application/pdf          (with a Content-Disposition and an MD5)
    ///   message/rfc822           (nesting a second envelope and a second body)
    /// ```
    ///
    /// That is what a mail client actually sends for a reply-with-attachment, and it exercises the
    /// three structurally different single-part forms the grammar has — `body-type-text` (which
    /// carries a line count), `body-type-basic` (which does not) and `body-type-msg` (which nests an
    /// envelope *and* a body *and* a line count) — plus multipart nesting two levels deep and the
    /// extension fields on both.
    private static let bodyStructure = """
        BODYSTRUCTURE \
        ((\
        ("text" "plain" ("charset" "utf-8") NIL NIL "quoted-printable" 2234 48 NIL NIL NIL NIL)\
        ("text" "html" ("charset" "utf-8") NIL NIL "quoted-printable" 8871 132 NIL NIL NIL NIL) \
        "alternative" ("boundary" "----=_Part_2_1721200462") NIL NIL NIL)\
        ("application" "pdf" ("name" "quarterly-report.pdf") NIL NIL "base64" 189342 \
        "d41d8cd98f00b204e9800998ecf8427e" ("attachment" ("filename" "quarterly-report.pdf")) NIL NIL)\
        ("message" "rfc822" NIL NIL NIL "7bit" 2048 \
        ("Tue, 16 Jul 2024 08:00:00 +0200" "Original subject" \
        (("Eve Example" NIL "eve" "example.com")) (("Eve Example" NIL "eve" "example.com")) \
        (("Eve Example" NIL "eve" "example.com")) (("Alice Example" NIL "alice" "example.com")) \
        NIL NIL NIL "<original.1721116800@example.com>") \
        ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 1024 20 NIL NIL NIL NIL) 40 \
        NIL NIL NIL NIL) \
        "mixed" ("boundary" "----=_Part_1_1721200461") NIL NIL NIL)
        """

    // MARK: - Corpora

    /// `messageCount` light FETCH responses followed by a tagged completion, as wire bytes.
    ///
    /// Every message carries UID, size and flags; every eighth also carries an envelope. This is
    /// what a flag sync over an already-known mailbox looks like.
    ///
    /// - Parameter messageCount: How many messages to describe.
    /// - Returns: The complete server output, ready to feed to a `ResponseParser`.
    public static func sweepBytes(messageCount: Int = defaultMessageCount) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(messageCount * 128)
        for number in 1...messageCount {
            buffer.writeString("* \(number) FETCH (UID \(1_000 + number) RFC822.SIZE \(20_000 + number * 7)")
            buffer.writeString(" FLAGS (\\Seen \\Answered)")
            if number % 8 == 0 {
                buffer.writeString(" \(envelope(subject: "A subject line of entirely ordinary length"))")
            }
            buffer.writeString(")\r\n")
        }
        buffer.writeString("A001 OK [READ-WRITE] Fetch completed (0.001 + 0.000 secs).\r\n")
        return buffer
    }

    /// The number of parse events ``sweepBytes(messageCount:)`` should produce.
    ///
    /// A message yields a `start`, one event per attribute, and a `finish`; the tagged completion
    /// yields one more. Used to assert that the corpus is what the benchmarks think it is.
    ///
    /// - Parameter messageCount: The message count passed to ``sweepBytes(messageCount:)``.
    /// - Returns: The expected number of parsed responses.
    public static func expectedSweepEventCount(messageCount: Int = defaultMessageCount) -> Int {
        let perMessage = 1 + 3 + 1  // start, UID + size + flags, finish
        let envelopes = messageCount / 8
        return messageCount * perMessage + envelopes + 1
    }

    /// `messageCount` heavy FETCH responses followed by a tagged completion, as wire bytes.
    ///
    /// Each message carries UID, flags, internal date, size, a full envelope and the nested body
    /// structure described above — i.e. what a client asks for when it populates a message list.
    /// Roughly 1 KB of grammar per message, against ~70 bytes for ``sweepBytes(messageCount:)``.
    ///
    /// - Parameter messageCount: How many messages to describe.
    /// - Returns: The complete server output, ready to feed to a `ResponseParser`.
    public static func bodyStructureBytes(messageCount: Int) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(messageCount * 1_400)
        for number in 1...messageCount {
            buffer.writeString("* \(number) FETCH (UID \(19_000 + number)")
            buffer.writeString(" FLAGS (\\Seen)")
            buffer.writeString(" INTERNALDATE \"17-Jul-2024 09:14:22 +0200\"")
            buffer.writeString(" RFC822.SIZE \(203_000 + number * 13)")
            buffer.writeString(" \(envelope(subject: "Re: Quarterly report, revised (\(number))"))")
            buffer.writeString(" \(bodyStructure)")
            buffer.writeString(")\r\n")
        }
        buffer.writeString("A002 OK Fetch completed (0.042 + 0.000 secs).\r\n")
        return buffer
    }

    /// Everything a client sees that is not a message body, as wire bytes.
    ///
    /// One connect-to-logout session: capabilities, `ID`, `NAMESPACE`, the mailbox tree, `LSUB`,
    /// `STATUS`, the full `SELECT` preamble with its response codes, a `SEARCH` and an `ESEARCH`
    /// result, an unsolicited flag update, an `EXPUNGE`, a continuation request, and `BYE`. Small in
    /// bytes, wide in grammar — most of the response types a client has to handle appear exactly
    /// here and nowhere else in this corpus.
    ///
    /// - Returns: The complete server output, ready to feed to a `ResponseParser`.
    public static func sessionBytes() -> ByteBuffer {
        let capabilities =
            "IMAP4rev1 SASL-IR LOGIN-REFERRALS ID ENABLE IDLE LITERAL+ CONDSTORE QRESYNC MOVE "
            + "SPECIAL-USE UIDPLUS ESEARCH LIST-EXTENDED LIST-STATUS BINARY NAMESPACE"
        var buffer = ByteBuffer()
        buffer.writeString(
            """
            * OK [CAPABILITY \(capabilities)] Server ready.\r
            * CAPABILITY \(capabilities)\r
            A001 OK Pre-login capabilities listed, post-login capabilities have more.\r
            * ID ("name" "benchmark-server" "version" "2.3.21")\r
            A002 OK ID completed (0.001 + 0.000 secs).\r
            * NAMESPACE (("" "/")) NIL NIL\r
            A003 OK Namespace completed (0.001 + 0.000 secs).\r
            * LIST (\\HasNoChildren) "/" "INBOX"\r
            * LIST (\\HasChildren \\Noselect) "/" "Archive"\r
            * LIST (\\HasNoChildren \\Archive) "/" "Archive/2024"\r
            * LIST (\\HasNoChildren \\Sent) "/" "Sent"\r
            * LIST (\\HasNoChildren \\Drafts) "/" "Drafts"\r
            * LIST (\\HasNoChildren \\Junk) "/" "Junk"\r
            * LIST (\\HasNoChildren \\Trash) "/" "Trash"\r
            * LIST (\\HasNoChildren) "/" "Notes"\r
            A004 OK List completed (0.002 + 0.000 secs).\r
            * LSUB () "/" "INBOX"\r
            * LSUB () "/" "Sent"\r
            A005 OK Lsub completed (0.001 + 0.000 secs).\r
            * STATUS "INBOX" (MESSAGES 12345 UIDNEXT 20001 UIDVALIDITY 1437559275 UNSEEN 3 HIGHESTMODSEQ 987654)\r
            A006 OK Status completed (0.001 + 0.000 secs).\r
            * FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft $Forwarded)\r
            * OK [PERMANENTFLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft $Forwarded \\*)] Flags permitted.\r
            * 12345 EXISTS\r
            * 0 RECENT\r
            * OK [UNSEEN 12342] First unseen.\r
            * OK [UIDVALIDITY 1437559275] UIDs valid\r
            * OK [UIDNEXT 20001] Predicted next UID\r
            * OK [HIGHESTMODSEQ 987654] Highest\r
            A007 OK [READ-WRITE] Select completed (0.003 + 0.000 secs).\r
            * SEARCH 12340 12341 12342\r
            A008 OK Search completed (0.004 + 0.000 secs).\r
            * ESEARCH (TAG "A009") UID COUNT 3 MIN 12340 MAX 12342\r
            A009 OK Search completed (0.004 + 0.000 secs).\r
            * 12343 FETCH (FLAGS (\\Seen \\Answered) UID 19998 MODSEQ (987655))\r
            * 12344 EXPUNGE\r
            * 12344 EXISTS\r
            A010 OK Store completed (0.002 + 0.000 secs).\r
            + Ready for literal data\r
            A011 OK [APPENDUID 1437559275 20001] Append completed (0.005 + 0.000 secs).\r
            * BYE Logging out\r
            A012 OK Logout completed (0.001 + 0.000 secs).\r\n
            """
        )
        return buffer
    }

    /// One FETCH response whose `BODY[TEXT]` is a literal of `byteCount` bytes.
    ///
    /// This is the streaming path: the parser reports the literal as a `streamingBegin`, a run of
    /// `streamingBytes` and a `streamingEnd`, never holding the whole payload in one piece. It is
    /// the case that has to stay zero-copy through the migration.
    ///
    /// - Parameter byteCount: The size of the literal payload.
    /// - Returns: The complete server output, ready to feed to a `ResponseParser`.
    public static func literalFetchBytes(byteCount: Int) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(byteCount + 64)
        buffer.writeString("* 1 FETCH (UID 1234 BODY[TEXT] {\(byteCount)}\r\n")
        // Printable ASCII, so the payload can also be re-encoded as a quoted string if a
        // benchmark ever wants that; the parser does not care either way.
        let pattern = ByteBuffer(string: String(repeating: "0123456789abcdef", count: 64)).readableBytesView
        var remaining = byteCount
        while remaining > 0 {
            let take = min(remaining, pattern.count)
            buffer.writeBytes(pattern.prefix(take))
            remaining -= take
        }
        buffer.writeString(")\r\n")
        return buffer
    }
}
