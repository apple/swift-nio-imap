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
    
    /// IMAPv4 `envelope`
    public struct Envelope: Equatable {
        public var date: NString
        public var subject: NString
        public var from: [IMAPCore.Address]
        public var sender: [IMAPCore.Address]
        public var reply: [IMAPCore.Address]
        public var to: [IMAPCore.Address]
        public var cc: [IMAPCore.Address]
        public var bcc: [IMAPCore.Address]
        public var inReplyTo: NString
        public var messageID: NString
        
        public static func date(_ date: NString, subject: IMAPCore.NString, from: [IMAPCore.Address], sender: [IMAPCore.Address], reply: [IMAPCore.Address], to: [IMAPCore.Address], cc: [IMAPCore.Address], bcc: [IMAPCore.Address], inReplyTo: IMAPCore.NString, messageID: IMAPCore.NString) -> Self {
            return Self(date: date, subject: subject, from: from, sender: sender, reply: reply, to: to, cc: cc, bcc: bcc, inReplyTo: inReplyTo, messageID: messageID)
        }
    }
    
}
