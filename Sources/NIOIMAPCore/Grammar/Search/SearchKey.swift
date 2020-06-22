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
public indirect enum SearchKey: Equatable {
    case all
    case answered
    case deleted
    case flagged
    case new
    case old
    case recent
    case seen
    case unanswered
    case undeleted
    case unflagged
    case unseen
    case draft
    case undraft
    case bcc(ByteBuffer)
    case before(Date)
    case body(ByteBuffer)
    case cc(ByteBuffer)
    case from(ByteBuffer)
    case keyword(Flag.Keyword)
    case on(Date)
    case since(Date)
    case subject(ByteBuffer)
    case text(ByteBuffer)
    case to(ByteBuffer)
    case unkeyword(Flag.Keyword)
    case header(String, ByteBuffer)
    case messageSizeLarger(Int)
    case not(SearchKey)
    case or(SearchKey, SearchKey)
    case sentBefore(Date)
    case sentOn(Date)
    case sentSince(Date)
    case messageSizeSmaller(Int)
    case uid(UIDSet)
    case sequenceNumbers(SequenceSet)
    case array([SearchKey])
    case older(Int)
    case younger(Int)
    case filter(String)
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeSearchKeys(_ keys: [SearchKey]) -> Int {
        self.writeArray(keys) { (element, self) in
            self.writeSearchKey(element)
        }
    }

    @discardableResult mutating func writeSearchKey(_ key: SearchKey) -> Int {
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
                self.writeString("BCC ") +
                self.writeIMAPString(str)

        case .before(let date):
            return
                self.writeString("BEFORE ") +
                self.writeDate(date)

        case .body(let str):
            return
                self.writeString("BODY ") +
                self.writeIMAPString(str)

        case .cc(let str):
            return
                self.writeString("CC ") +
                self.writeIMAPString(str)

        case .from(let str):
            return
                self.writeString("FROM ") +
                self.writeIMAPString(str)

        case .keyword(let flag):
            return
                self.writeString("KEYWORD ") +
                self.writeFlagKeyword(flag)

        case .on(let date):
            return
                self.writeString("ON ") +
                self.writeDate(date)

        case .since(let date):
            return
                self.writeString("SINCE ") +
                self.writeDate(date)

        case .subject(let str):
            return
                self.writeString("SUBJECT ") +
                self.writeIMAPString(str)

        case .text(let str):
            return
                self.writeString("TEXT ") +
                self.writeIMAPString(str)

        case .to(let str):
            return
                self.writeString("TO ") +
                self.writeIMAPString(str)

        case .unkeyword(let keyword):
            return
                self.writeString("UNKEYWORD ") +
                self.writeFlagKeyword(keyword)

        case .header(let field, let value):
            return
                self.writeString("HEADER ") +
                self.writeAString(field) +
                self.writeSpace() +
                self.writeIMAPString(value)

        case .messageSizeLarger(let n):
            return self.writeString("LARGER \(n)")

        case .not(let key):
            return
                self.writeString("NOT ") +
                self.writeSearchKey(key)

        case .or(let k1, let k2):
            return
                self.writeString("OR ") +
                self.writeSearchKey(k1) +
                self.writeSpace() +
                self.writeSearchKey(k2)

        case .messageSizeSmaller(let n):
            return self.writeString("SMALLER \(n)")

        case .uid(let set):
            return
                self.writeString("UID ") +
                self.writeUIDSet(set)

        case .sequenceNumbers(let set):
            return self.writeSequenceSet(set)

        case .array(let array):
            return self.writeSearchKeys(array)
        case .younger(let seconds):
            return self.writeString("YOUNGER \(seconds)")
        case .older(let seconds):
            return self.writeString("OLDER \(seconds)")
        case .filter(let filterName):
            return
                self.writeString("FILTER ") +
                self.writeFilterName(filterName)
        case .sentBefore(let date):
            return
                self.writeString("SENTBEFORE ") +
                self.writeDate(date)
        case .sentOn(let date):
            return
                self.writeString("SENTON ") +
                self.writeDate(date)
        case .sentSince(let date):
            return
                self.writeString("SENTSINCE ") +
                self.writeDate(date)
        }
    }
}
