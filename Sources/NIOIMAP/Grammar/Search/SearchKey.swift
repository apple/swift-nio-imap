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

// MARK: - IMAP
extension ByteBuffer {
    
    @discardableResult mutating func writeSearchKeys(_ keys: [NIOIMAP.SearchKey]) -> Int {
        return self.writeArray(keys) { (element, self) in
            self.writeSearchKey(element)
        }
    }
    
    @discardableResult mutating func writeSearchKey(_ key: NIOIMAP.SearchKey) -> Int {
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
        
        case .larger(let n):
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
        
        case .sent(let type):
            return self.writeSearchSentType(type)
        
        case .smaller(let n):
            return self.writeString("SMALLER \(n)")
        
        case .uid(let set):
            return
                self.writeString("UID ") +
                self.writeSequenceSet(set)
        
        case .sequenceSet(let set):
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
        }
    }
    
}
