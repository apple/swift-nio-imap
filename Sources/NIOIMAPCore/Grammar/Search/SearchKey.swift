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

import struct NIO.ByteBuffer

/// Represents a search criterion for the `SEARCH` command.
///
/// Search keys are used to query mailboxes for messages matching specified criteria.
/// The `SEARCH` command is defined in [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4),
/// with extensions provided by multiple RFCs including [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032),
/// [RFC 5466](https://datatracker.ietf.org/doc/html/rfc5466), [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162),
/// and [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474).
///
/// Search keys can be combined using logical operators (``and(_:)``, ``or(_:_:)``, ``not(_:)``)
/// to create complex search expressions. The server returns a list of message sequence numbers
/// or UIDs matching all specified criteria.
///
/// ### Examples
///
/// ```
/// C: A001 SEARCH ALL
/// S: * SEARCH 1 3 5 7 9
/// S: A001 OK SEARCH completed
/// ```
///
/// The ``all`` case matches all messages. The server returns ``Response/untagged(_:)`` containing
/// ``ResponsePayload/mailboxData(_:)`` with ``MailboxData/search(_:_:)`` wrapping the matching sequence numbers.
///
/// ```
/// C: A002 SEARCH NOT DELETED SEEN
/// S: * SEARCH 2 4 6 8
/// S: A002 OK SEARCH completed
/// ```
///
/// The ``not(_:)`` case with ``seen`` case matches messages that are not deleted and have been seen.
///
/// ## Related types
///
/// - ``SearchReturnOption``: Options controlling the format of search results
/// - ``Command/search(key:charset:returnOptions:)`` and ``Command/uidSearch(key:charset:returnOptions:)`` commands that perform searches
/// - ``MailboxData/search(_:_:)``: Server response containing search results
///
/// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501), [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032), [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162), [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
public indirect enum SearchKey: Hashable, Sendable {
    /// Matches all messages in the mailbox.
    ///
    /// The default initial key for combining multiple search criteria with `AND` logic.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case all

    /// Matches messages with the `\Answered` flag set.
    ///
    /// The `\Answered` flag indicates a message that has been answered.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case answered

    /// Matches messages with the `\Deleted` flag set.
    ///
    /// The `\Deleted` flag marks messages for deletion by the server.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case deleted

    /// Matches messages with the `\Flagged` flag set.
    ///
    /// The `\Flagged` flag marks important or urgent messages.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case flagged

    /// Matches messages with the `\Recent` flag set but not the `\Seen` flag.
    ///
    /// Functionally equivalent to the search key combination `(RECENT UNSEEN)`.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case new

    /// Matches messages without the `\Recent` flag set.
    ///
    /// Functionally equivalent to `NOT RECENT`, as opposed to ``new`` (which is "NOT NEW").
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case old

    /// Matches messages with the `\Recent` flag set.
    ///
    /// The `\Recent` flag indicates a message that has arrived since the last session.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case recent

    /// Matches messages with the `\Seen` flag set.
    ///
    /// The `\Seen` flag indicates a message that has been read.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case seen

    /// Matches messages without the `\Answered` flag set.
    ///
    /// The negation of ``answered``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case unanswered

    /// Matches messages without the `\Deleted` flag set.
    ///
    /// The negation of ``deleted``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case undeleted

    /// Matches messages without the `\Flagged` flag set.
    ///
    /// The negation of ``flagged``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case unflagged

    /// Matches messages without the `\Seen` flag set.
    ///
    /// The negation of ``seen``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case unseen

    /// Matches messages with the `\Draft` flag set.
    ///
    /// The `\Draft` flag marks messages that are incomplete and not yet sent.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case draft

    /// Matches messages without the `\Draft` flag set.
    ///
    /// The negation of ``draft``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case undraft

    /// Matches messages containing the specified string in the BCC (blind carbon copy) field.
    ///
    /// The search string is performed on the envelope structure’s BCC field.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case bcc(ByteBuffer)

    /// Matches messages whose internal date (disregarding time and timezone) is earlier than the specified date.
    ///
    /// The `BEFORE` search key compares only the date portion, not the time.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case before(IMAPCalendarDay)

    /// Matches messages containing the specified string in the message body.
    ///
    /// The search is performed on the complete message body, including both text and encoded parts.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case body(ByteBuffer)

    /// Matches messages containing the specified string in the CC (carbon copy) field.
    ///
    /// The search string is performed on the envelope structure’s CC field.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case cc(ByteBuffer)

    /// Matches messages containing the specified string in the FROM field.
    ///
    /// The search string is performed on the envelope structure’s FROM field.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case from(ByteBuffer)

    /// Matches messages with the specified keyword flag set.
    ///
    /// Keyword flags are user-defined flags that don’t start with a backslash.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case keyword(Flag.Keyword)

    /// Matches messages whose internal date (disregarding time and timezone) is exactly the specified date.
    ///
    /// The `ON` search key compares only the date portion, not the time.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case on(IMAPCalendarDay)

    /// Matches messages whose internal date (disregarding time and timezone) is on or later than the specified date.
    ///
    /// The `SINCE` search key compares only the date portion, not the time.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case since(IMAPCalendarDay)

    /// Matches messages containing the specified string in the SUBJECT field.
    ///
    /// The search string is performed on the envelope structure’s SUBJECT field.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case subject(ByteBuffer)

    /// Matches messages containing the specified string in either the header or body of the message.
    ///
    /// Performs a broad search across the entire message content.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case text(ByteBuffer)

    /// Matches messages containing the specified string in the TO field.
    ///
    /// The search string is performed on the envelope structure’s TO field.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case to(ByteBuffer)

    /// Matches messages without the specified keyword flag set.
    ///
    /// The negation of ``keyword(_:)``.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case unkeyword(Flag.Keyword)

    /// Matches messages containing a header field with the specified name and text value.
    ///
    /// The header field name and text value are both searched for. If the text value is empty,
    /// this matches all messages that contain the specified header field, regardless of its value.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case header(String, ByteBuffer)

    /// Matches messages larger than the specified number of octets.
    ///
    /// The size comparison is based on the RFC 2822 message size.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case messageSizeLarger(Int)

    /// Matches messages that do not match the specified search key.
    ///
    /// Negates the given search key. Search keys are combined recursively using this case.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case not(SearchKey)

    /// Matches messages that match either of the two specified search keys.
    ///
    /// A logical `OR` operation between two search keys.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case or(SearchKey, SearchKey)

    /// Matches messages whose RFC 2822 Date header (disregarding time and timezone) is earlier than the specified date.
    ///
    /// Differs from ``before(_:)`` which uses the message’s internal date. `SENTBEFORE` uses the message’s
    /// Date: header field instead. From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case sentBefore(IMAPCalendarDay)

    /// Matches messages whose RFC 2822 Date header (disregarding time and timezone) is exactly the specified date.
    ///
    /// Differs from ``on(_:)`` which uses the message’s internal date. `SENTON` uses the message’s
    /// Date: header field instead. From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case sentOn(IMAPCalendarDay)

    /// Matches messages whose RFC 2822 Date header (disregarding time and timezone) is on or later than the specified date.
    ///
    /// Differs from ``since(_:)`` which uses the message’s internal date. `SENTSINCE` uses the message’s
    /// Date: header field instead. From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case sentSince(IMAPCalendarDay)

    /// Matches messages smaller than the specified number of octets.
    ///
    /// The size comparison is based on the RFC 2822 message size.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case messageSizeSmaller(Int)

    /// Matches messages with unique identifiers (UIDs) in the specified UID set.
    ///
    /// Sequence set ranges are permitted in the UID set. This allows searching for a specific
    /// set of messages by their unique identifiers.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case uid(LastCommandSet<UID>)

    /// Matches messages with UIDs after the specified UID.
    ///
    /// An extension search key that references UIDs relative to the last `SEARCH` result.
    /// From [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182).
    case uidAfter(LastCommandMessageID<UID>)

    /// Matches messages with UIDs before the specified UID.
    ///
    /// An extension search key that references UIDs relative to the last `SEARCH` result.
    /// From [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182).
    case uidBefore(LastCommandMessageID<UID>)

    /// Matches messages with sequence numbers in the specified sequence set.
    ///
    /// Sequence set ranges are permitted. This allows searching for a specific set of messages
    /// by their message sequence numbers.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case sequenceNumbers(LastCommandSet<SequenceNumber>)

    /// Matches messages that match all of the given search keys.
    ///
    /// A logical `AND` operation combining all search keys in the array.
    /// An empty array matches no messages.
    /// From [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4).
    case and([SearchKey])

    /// Matches messages older than the specified number of seconds.
    ///
    /// The age is calculated from the current time to the message’s internal date.
    /// From [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032).
    case older(Int)

    /// Matches messages younger than the specified number of seconds.
    ///
    /// The age is calculated from the current time to the message’s internal date.
    /// From [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032).
    case younger(Int)

    /// References a server-side saved filter by name.
    ///
    /// Allows searching using pre-defined server-side filters, identified by name.
    /// From [RFC 5466](https://datatracker.ietf.org/doc/html/rfc5466).
    case filter(String)

    /// Matches messages with a modification sequence (MODSEQ) value matching the specified criteria.
    ///
    /// The modification sequence allows searching based on when messages were last modified,
    /// useful in CONDSTORE-enabled mailboxes.
    /// From [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1).
    case modificationSequence(SearchModificationSequence)

    /// Matches messages with the specified ``EmailID``.
    ///
    /// The `EMAILID` search key is part of the OBJECTID extension and allows searching by
    /// message object identifier.
    /// From [RFC 8474 Section 3](https://datatracker.ietf.org/doc/html/rfc8474#section-3).
    case emailID(EmailID)

    /// Matches messages with the specified ``ThreadID``.
    ///
    /// The `THREADID` search key is part of the OBJECTID extension and allows searching by
    /// message thread object identifier.
    /// From [RFC 8474 Section 3](https://datatracker.ietf.org/doc/html/rfc8474#section-3).
    case threadID(ThreadID)
}

extension SearchKey {
    /// Indicates whether this search key uses string comparisons at any level.
    ///
    /// This property checks if this search key or any nested search keys (through ``not(_:)``, ``or(_:_:)``,
    /// or ``and(_:)``) use string-based searches like ``bcc(_:)``, ``body(_:)``, ``cc(_:)``, ``from(_:)``,
    /// ``subject(_:)``, ``text(_:)``, ``to(_:)``, or ``header(_:_:)``.
    ///
    /// This is used internally to determine if a `CHARSET UTF-8` specification is needed in the `SEARCH` command
    /// when the search includes string-based criteria.
    ///
    /// - Returns: `true` if this key or any nested key uses string comparisons; `false` otherwise
    var usesString: Bool {
        switch self {
        case .all,
            .answered,
            .deleted,
            .flagged,
            .new,
            .old,
            .recent,
            .seen,
            .unanswered,
            .undeleted,
            .unflagged,
            .unseen,
            .draft,
            .undraft,
            .before,
            .keyword,
            .on,
            .since,
            .unkeyword,
            .messageSizeLarger,
            .sentBefore,
            .sentOn,
            .sentSince,
            .messageSizeSmaller,
            .uid,
            .uidAfter,
            .uidBefore,
            .sequenceNumbers,
            .older,
            .younger,
            .modificationSequence,
            .filter,
            .emailID,
            .threadID:
            return false

        case .bcc,
            .body,
            .cc,
            .from,
            .subject,
            .text,
            .to,
            .header:
            return true

        case .not(let key):
            return key.usesString
        case .or(let keyA, let keyB):
            return keyA.usesString || keyB.usesString
        case .and(let keys):
            return keys.contains(where: \.usesString)
        }
    }
}

extension SearchKey {
    fileprivate var count: Int {
        switch self {
        case .all,
            .answered,
            .bcc,
            .before,
            .body,
            .cc,
            .deleted,
            .flagged,
            .from,
            .keyword,
            .new,
            .old,
            .on,
            .recent,
            .seen,
            .since,
            .subject,
            .text,
            .to,
            .unanswered,
            .undeleted,
            .unflagged,
            .unkeyword,
            .unseen,
            .draft,
            .header,
            .messageSizeLarger,
            .sentBefore,
            .sentOn,
            .sentSince,
            .messageSizeSmaller,
            .uid,
            .uidAfter,
            .uidBefore,
            .undraft,
            .sequenceNumbers,
            .older,
            .younger,
            .modificationSequence,
            .filter,
            .emailID,
            .threadID:
            return 1
        case .not(let inner):
            return 1 + inner.count
        case .or(let lhs, let rhs):
            return lhs.count + rhs.count
        case .and(let keys):
            return keys.reduce(into: 0) { $0 += $1.count }
        }
    }
}

extension SearchKey: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            _ = $0.writeSearchKey(self)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchKey(_ key: SearchKey, encloseInParenthesisIfNeeded: Bool = false) -> Int
    {
        let encloseInParenthesis = encloseInParenthesisIfNeeded && key.count > 1
        guard encloseInParenthesis else {
            return _writeSearchKey(key)
        }
        return writeString("(") + _writeSearchKey(key) + writeString(")")
    }

    private mutating func _writeSearchKey(_ key: SearchKey) -> Int {
        switch key {
        case .all:
            return self.writeString("ALL")
        case .answered:
            return self.writeString("ANSWERED")
        case .deleted:
            return self.writeString("DELETED")
        case .flagged:
            return self.writeString("FLAGGED")
        case .new:
            return self.writeString("NEW")
        case .old:
            return self.writeString("OLD")
        case .recent:
            return self.writeString("RECENT")
        case .seen:
            return self.writeString("SEEN")
        case .unanswered:
            return self.writeString("UNANSWERED")
        case .undeleted:
            return self.writeString("UNDELETED")
        case .unflagged:
            return self.writeString("UNFLAGGED")
        case .unseen:
            return self.writeString("UNSEEN")
        case .draft:
            return self.writeString("DRAFT")
        case .undraft:
            return self.writeString("UNDRAFT")
        case .bcc(let str):
            return
                self.writeString("BCC ") + self.writeIMAPString(str)

        case .before(let date):
            return
                self.writeString("BEFORE ") + self.writeDate(date)

        case .body(let str):
            return
                self.writeString("BODY ") + self.writeIMAPString(str)

        case .cc(let str):
            return
                self.writeString("CC ") + self.writeIMAPString(str)

        case .from(let str):
            return
                self.writeString("FROM ") + self.writeIMAPString(str)

        case .keyword(let flag):
            return
                self.writeString("KEYWORD ") + self.writeFlagKeyword(flag)

        case .on(let date):
            return
                self.writeString("ON ") + self.writeDate(date)

        case .since(let date):
            return
                self.writeString("SINCE ") + self.writeDate(date)

        case .subject(let str):
            return
                self.writeString("SUBJECT ") + self.writeIMAPString(str)

        case .text(let str):
            return
                self.writeString("TEXT ") + self.writeIMAPString(str)

        case .to(let str):
            return
                self.writeString("TO ") + self.writeIMAPString(str)

        case .unkeyword(let keyword):
            return
                self.writeString("UNKEYWORD ") + self.writeFlagKeyword(keyword)

        case .header(let field, let value):
            return
                self.writeString("HEADER ") + self.writeIMAPString(field) + self.writeSpace()
                + self.writeIMAPString(value)

        case .messageSizeLarger(let n):
            return self.writeString("LARGER \(n)")

        case .not(let key):
            return
                self.writeString("NOT ") + self.writeSearchKey(key, encloseInParenthesisIfNeeded: true)

        case .or(let k1, let k2):
            return
                self.writeString("OR ") + self.writeSearchKey(k1, encloseInParenthesisIfNeeded: true)
                + self.writeSpace() + self.writeSearchKey(k2, encloseInParenthesisIfNeeded: true)

        case .messageSizeSmaller(let n):
            return self.writeString("SMALLER \(n)")

        case .uid(let set):
            return
                self.writeString("UID ") + self.writeLastCommandSet(set)

        case .uidAfter(let uid):
            return
                self.writeString("UIDAFTER ") + self.writeLastCommandMessageID(uid)

        case .uidBefore(let uid):
            return
                self.writeString("UIDBEFORE ") + self.writeLastCommandMessageID(uid)

        case .sequenceNumbers(let set):
            return self.writeLastCommandSet(set)

        case .and(let keys):
            if keys.count == 0 {
                return self.writeString("()")
            } else if keys.count == 1, let key = keys.first {
                return self.writeSearchKey(key, encloseInParenthesisIfNeeded: true)
            } else {
                return keys.enumerated().reduce(0) { (size, row) in
                    let (i, key) = row
                    return
                        size + self.writeSearchKey(key, encloseInParenthesisIfNeeded: true)
                        + self.write(if: i < keys.count - 1) { () -> Int in
                            self.writeString(" ")
                        }
                }
            }
        case .younger(let seconds):
            return self.writeString("YOUNGER \(seconds)")
        case .older(let seconds):
            return self.writeString("OLDER \(seconds)")
        case .filter(let filterName):
            return
                self.writeString("FILTER \(filterName)")
        case .sentBefore(let date):
            return
                self.writeString("SENTBEFORE ") + self.writeDate(date)
        case .sentOn(let date):
            return
                self.writeString("SENTON ") + self.writeDate(date)
        case .sentSince(let date):
            return
                self.writeString("SENTSINCE ") + self.writeDate(date)

        case .modificationSequence(let seq):
            return self.writeSearchModificationSequence(seq)

        case .emailID(let id):
            return self.writeString("EMAILID ") + self.writeEmailID(id)

        case .threadID(let id):
            return self.writeString("THREADID ") + self.writeThreadID(id)
        }
    }
}
