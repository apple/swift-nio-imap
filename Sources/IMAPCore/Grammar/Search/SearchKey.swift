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



extension IMAPCore {
 
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
        case bcc(String)
        case before(Date)
        case body(String)
        case cc(String)
        case from(String)
        case keyword(Flag.Keyword)
        case on(Date)
        case since(Date)
        case subject(String)
        case text(String)
        case to(String)
        case unkeyword(Flag.Keyword)
        case header(String, String)
        case larger(Int)
        case not(SearchKey)
        case or(SearchKey, SearchKey)
        case sent(SearchSentType)
        case smaller(Int)
        case uid([IMAPCore.SequenceRange])
        case sequenceSet([IMAPCore.SequenceRange])
        case array([IMAPCore.SearchKey])
        case older(Int)
        case younger(Int)
        case filter(String)
    }
    
}
