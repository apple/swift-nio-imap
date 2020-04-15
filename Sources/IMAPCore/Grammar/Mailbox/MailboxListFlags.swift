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



extension IMAPCore.Mailbox.List {
    
    /// IMAPv4 `mbx-list-flags`
    public struct Flags: Equatable {
        public var oFlags: [OFlag]
        public var sFlag: SFlag?
        
        public static func oFlags(_ oFlags: [OFlag], sFlag: SFlag?) -> Self {
            return Self(oFlags: oFlags, sFlag: sFlag)
        }
    }
    
}
