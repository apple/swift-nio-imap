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

/// IMAPv4 `search-key`
public indirect enum SearchKey: Hashable {
    /// RFC 3501: All messages in the mailbox; the default initial key for ANDing.
    case all

    /// RFC 3501: Messages with the `\Answered` flag set.
    case answered

    /// RFC 3501: Messages with the `\Deleted` flag set.
    case deleted

    /// RFC 3501: Messages with the `\Flagged` flag set.
    case flagged

    /// RFC 3501: Messages that have the `\Recent` flag set but not the `\Seen` flag. This is functionally equivalent to "(RECENT UNSEEN)".
    case new

    /// RFC 3501: Messages that functionally equivalent to "NOT RECENT" (as opposed to "NOT NEW").
    case old

    /// RFC 3501: Messages that have the `\Recent` flag set.
    case recent

    /// RFC 3501: Messages that have the `\Seen` flag set.
    case seen

    /// RFC 3501: Messages that do not have the `\Answered` flag set.
    case unanswered

    /// RFC 3501: Messages that do not have the `\Delete` flag set.
    case undeleted

    /// RFC 3501: Messages that do not have the `\Flagged` flag set.
    case unflagged

    /// RFC 3501: Messages that do not have the `\Seen` flag set.
    case unseen

    /// RFC 3501: Messages with the `\Draft` flag set.
    case draft

    /// RFC 3501: Messages that do not have the `\Draft` flag set.
    case undraft

    /// RFC 3501: Messages that contain the specified string in the envelope structure’s BCC field.
    case bcc(ByteBuffer)

    /// RFC 3501: Messages whose internal date (disregarding time and timezone) is earlier than the specified date.
    case before(IMAPCalendarDay)

    /// RFC 3501: Messages that contain the specified string in the body of the message.
    case body(ByteBuffer)

    /// RFC 3501: Messages that contain the specified string in the envelope structure’s CC field.
    case cc(ByteBuffer)

    /// RFC 3501: Messages that contain the specified string in the envelope structure’s FROM field.
    case from(ByteBuffer)

    /// RFC 3501: Messages with the specified keyword flag set.
    case keyword(Flag.Keyword)

    /// RFC 3501: Messages whose internal date (disregarding time and timezone) is within the specified date.
    case on(IMAPCalendarDay)

    /// RFC 3501: Messages whose internal date (disregarding time and timezone) is within or later than the specified date.
    case since(IMAPCalendarDay)

    /// RFC 3501: Messages that contain the specified string in the envelope structure’s SUBJECT field.
    case subject(ByteBuffer)

    /// RFC 3501: Messages that contain the specified string in the header or body of the message.
    case text(ByteBuffer)

    /// RFC 3501: Messages that contain the specified string in the envelope structure’s TO field.
    case to(ByteBuffer)

    /// RFC 3501: Messages that do not have the specified keyword flag set.
    case unkeyword(Flag.Keyword)

    /// RFC 3501: Messages that have a header with the specified field-name (as defined in [RFC-2822]) and that contains the specified string in the text of the header (what comes after the colon). If the string to search is zero-length, this matches all messages that have a header the contents.
    case header(String, ByteBuffer)

    /// RFC 3501: Messages with an [RFC-2822] size larger than the specified number of octets.
    case messageSizeLarger(Int)

    /// RFC 3501: Messages that do not match the specified search key.
    case not(SearchKey)

    /// RFC 3501: Messages that match either search key.
    case or(SearchKey, SearchKey)

    /// RFC 3501: Messages whose [RFC-2822] Date: header (disregarding time and timezone) is earlier than the specified date.
    case sentBefore(IMAPCalendarDay)

    /// RFC 3501: Messages whose [RFC-2822] Date: header (disregarding time and timezone) is within the specified date.
    case sentOn(IMAPCalendarDay)

    /// RFC 3501: Messages whose [RFC-2822] Date: header (disregarding time and timezone) is within or later than the specified date.
    case sentSince(IMAPCalendarDay)

    /// RFC 3501: Messages with an [RFC-2822] size smaller than the specified number of octets.
    case messageSizeSmaller(Int)

    /// RFC 3501: Messages with unique identifiers corresponding to the specified unique identifier set. Sequence set ranges are permitted.
    case uid(LastCommandSet<UIDSetNonEmpty>)

    /// RFC 3501: Messages that match a given sequence set.
    case sequenceNumbers(LastCommandSet<SequenceRangeSet>)

    /// RFC 3501: Messages that match all of the given keys.
    case and([SearchKey])

    /// RFC 5032: Messages that are older than the given number of seconds.
    case older(Int)

    /// RFC 5032: Messages that are younger than the given number of seconds.
    case younger(Int)

    /// RFC 5466: References a stored filter by name on the server.
    case filter(String)

    /// RFC 7162
    case modificationSequence(SearchModificationSequence)
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
             .undraft,
             .sequenceNumbers,
             .older,
             .younger,
             .modificationSequence,
             .filter:
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

// MARK: - IMAP

extension _EncodeBuffer {
    @discardableResult mutating func writeSearchKeys(_ keys: [SearchKey]) -> Int {
        writeSearchKey(.and(keys))
    }

    @discardableResult mutating func writeSearchKey(_ key: SearchKey, encloseInParenthesisIfNeeded: Bool = false) -> Int {
        let encloseInParenthesis = encloseInParenthesisIfNeeded && key.count > 1
        if encloseInParenthesis {
            return _writeString("(") +
                _writeSearchKey(key) +
                _writeString(")")
        } else {
            return _writeSearchKey(key)
        }
    }

    private mutating func _writeSearchKey(_ key: SearchKey) -> Int {
        switch key {
        case .all:
            return self._writeString("ALL")
        case .answered:
            return self._writeString("ANSWERED")
        case .deleted:
            return self._writeString("DELETED")
        case .flagged:
            return self._writeString("FLAGGED")
        case .new:
            return self._writeString("NEW")
        case .old:
            return self._writeString("OLD")
        case .recent:
            return self._writeString("RECENT")
        case .seen:
            return self._writeString("SEEN")
        case .unanswered:
            return self._writeString("UNANSWERED")
        case .undeleted:
            return self._writeString("UNDELETED")
        case .unflagged:
            return self._writeString("UNFLAGGED")
        case .unseen:
            return self._writeString("UNSEEN")
        case .draft:
            return self._writeString("DRAFT")
        case .undraft:
            return self._writeString("UNDRAFT")
        case .bcc(let str):
            return
                self._writeString("BCC ") +
                self.writeIMAPString(str)

        case .before(let date):
            return
                self._writeString("BEFORE ") +
                self.writeDate(date)

        case .body(let str):
            return
                self._writeString("BODY ") +
                self.writeIMAPString(str)

        case .cc(let str):
            return
                self._writeString("CC ") +
                self.writeIMAPString(str)

        case .from(let str):
            return
                self._writeString("FROM ") +
                self.writeIMAPString(str)

        case .keyword(let flag):
            return
                self._writeString("KEYWORD ") +
                self.writeFlagKeyword(flag)

        case .on(let date):
            return
                self._writeString("ON ") +
                self.writeDate(date)

        case .since(let date):
            return
                self._writeString("SINCE ") +
                self.writeDate(date)

        case .subject(let str):
            return
                self._writeString("SUBJECT ") +
                self.writeIMAPString(str)

        case .text(let str):
            return
                self._writeString("TEXT ") +
                self.writeIMAPString(str)

        case .to(let str):
            return
                self._writeString("TO ") +
                self.writeIMAPString(str)

        case .unkeyword(let keyword):
            return
                self._writeString("UNKEYWORD ") +
                self.writeFlagKeyword(keyword)

        case .header(let field, let value):
            return
                self._writeString("HEADER ") +
                self.writeIMAPString(field) +
                self.writeSpace() +
                self.writeIMAPString(value)

        case .messageSizeLarger(let n):
            return self._writeString("LARGER \(n)")

        case .not(let key):
            return
                self._writeString("NOT ") +
                self.writeSearchKey(key, encloseInParenthesisIfNeeded: true)

        case .or(let k1, let k2):
            return
                self._writeString("OR ") +
                self.writeSearchKey(k1, encloseInParenthesisIfNeeded: true) +
                self.writeSpace() +
                self.writeSearchKey(k2, encloseInParenthesisIfNeeded: true)

        case .messageSizeSmaller(let n):
            return self._writeString("SMALLER \(n)")

        case .uid(let set):
            return
                self._writeString("UID ") +
                self.writeLastCommandSet(set)

        case .sequenceNumbers(let set):
            return self.writeLastCommandSet(set)

        case .and(let keys):
            if keys.count == 0 {
                return self._writeString("()")
            } else if keys.count == 1, let key = keys.first {
                return self.writeSearchKey(key, encloseInParenthesisIfNeeded: true)
            } else {
                return keys.enumerated().reduce(0) { (size, row) in
                    let (i, key) = row
                    return
                        size +
                        self.writeSearchKey(key, encloseInParenthesisIfNeeded: true) +
                        self.write(if: i < keys.count - 1) { () -> Int in
                            self._writeString(" ")
                        }
                }
            }
        case .younger(let seconds):
            return self._writeString("YOUNGER \(seconds)")
        case .older(let seconds):
            return self._writeString("OLDER \(seconds)")
        case .filter(let filterName):
            return
                self._writeString("FILTER \(filterName)")
        case .sentBefore(let date):
            return
                self._writeString("SENTBEFORE ") +
                self.writeDate(date)
        case .sentOn(let date):
            return
                self._writeString("SENTON ") +
                self.writeDate(date)
        case .sentSince(let date):
            return
                self._writeString("SENTSINCE ") +
                self.writeDate(date)

        case .modificationSequence(let seq):
            return self.writeSearchModificationSequence(seq)
        }
    }
}
