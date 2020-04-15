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

    public enum CommandType: Equatable {
        case capability
        case logout
        case noop
        case xcommand(String)
        case append(to: Mailbox, firstMessageMetadata: AppendMessage)
        case create(Mailbox, [CreateParameter])
        case delete(Mailbox)
        case examine(Mailbox, [SelectParameter])
        case list(ListSelectOptions?, Mailbox, MailboxPatterns, [IMAPCore.ReturnOption])
        case lsub(Mailbox, String)
        case rename(from: Mailbox, to: Mailbox, params: [RenameParameter])
        case select(Mailbox, [SelectParameter])
        case status(Mailbox, [StatusAttribute])
        case subscribe(Mailbox)
        case unsubscribe(Mailbox)
        case authenticate(String, InitialResponse?, [String])
        case login(String, String)
        case starttls
        case check
        case close
        case expunge
        case uid(UIDCommandType)
        case enable([Capability])
        case unselect
        case idleStart
        case idleFinish
        case copy([IMAPCore.SequenceRange], Mailbox)
        case fetch([IMAPCore.SequenceRange], FetchType, [FetchModifier])
        case store([IMAPCore.SequenceRange], [StoreModifier], StoreAttributeFlags)
        case search(returnOptions: [SearchReturnOption], program: SearchProgram)
        case move([IMAPCore.SequenceRange], Mailbox)
        case id([IDParameter])
        case namespace
    }

}
