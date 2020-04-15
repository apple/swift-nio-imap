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



extension IMAPCore.Mailbox {
    
    /// IMAPv4 `mailbox-data`
    public enum Data: Equatable {
        case flags([IMAPCore.Flag])
        case list(IMAPCore.Mailbox.List)
        case lsub(IMAPCore.Mailbox.List)
        case search(IMAPCore.ESearchResponse)
        case status(IMAPCore.Mailbox, [IMAPCore.StatusAttributeValue])
        case exists(Int)
        case namespace(IMAPCore.NamespaceResponse)
    }
    
}
