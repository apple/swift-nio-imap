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
    
    /// IMAPv4 `section-msgtext`
    public enum SectionMessageText: Equatable {
        case header
        case headerFields(_ fields: [String])
        case notHeaderFields(_ fields: [String])
        case text
    }
    
}
