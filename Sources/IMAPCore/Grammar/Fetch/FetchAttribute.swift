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
    
    /// IMAPv4 `fetch-att`
    public enum FetchAttribute: Equatable {
        case envelope
        case flags
        case internaldate
        case rfc822(RFC822?)
        case body(structure: Bool)
        case bodySection(_ section: SectionSpec?, Partial?)
        case bodyPeekSection(_ section: SectionSpec?, Partial?)
        case uid
        case modSequence(ModifierSequenceValue)
        case binary(peek: Bool, section: [Int], partial: Partial?)
        case binarySize(section: [Int])
    }
    
}
