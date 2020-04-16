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

// MARK: - IMAP
extension ByteBufferProtocol {
    
    @discardableResult mutating func writeCommandType(_ commandType: IMAPCore.CommandType) -> Int {
        switch commandType {
        case .capability:
            return self.writeCommandType_capability()
        case .logout:
            return self.writeCommandType_logout()
        case .noop:
            return self.writeCommandType_noop()
        case let .xcommand(command):
            return self.writeCommandType_xCommand(command)
        case let .append(to, firstMessageMetadata):
            return self.writeCommandType_append(to: to, firstMessageMetadata: firstMessageMetadata)
        case let .create(mailbox, params):
            return self.writeCommandType_create(mailbox: mailbox, parameters: params)
        case let .delete(mailbox):
            return self.writeCommandType_delete(mailbox: mailbox)
        case let .examine(mailbox, params):
            return self.writeCommandType_examine(mailbox: mailbox, parameters: params)
        case let .list(selectOptions, mailbox, mailboxPatterns, returnOptions):
            return self.writeCommandType_list(selectOptions: selectOptions, mailbox: mailbox, mailboxPatterns: mailboxPatterns, returnOptions: returnOptions)
        case let .lsub(mailbox, listMailbox):
            return self.writeCommandType_lsub(mailbox: mailbox, listMailbox: listMailbox)
        case let .rename(from, to, params):
            return self.writeCommandType_rename(from: from, to: to, parameters: params)
        case let .select(mailbox, params):
            return self.writeCommandType_select(mailbox: mailbox, params: params)
        case let .status(mailbox, attributes):
            return self.writeCommandType_status(mailbox: mailbox, attributes: attributes)
        case let .subscribe(mailbox):
            return self.writeCommandType_subscribe(mailbox: mailbox)
        case let .unsubscribe(mailbox):
            return self.writeCommandType_unsubscribe(mailbox: mailbox)
        case let .authenticate(type, initial, data):
            return self.writeCommandType_authenticate(type: type, initial: initial, data: data)
        case let .login(userid, password):
            return self.writeCommandType_login(userID: userid, password: password)
        case .starttls:
            return self.writeCommandType_startTLS()
        case .check:
            return self.writeCommandType_check()
        case .close:
            return self.writeCommandType_close()
        case .expunge:
            return self.writeCommandType_expunge()
        case .enable(let capabilities):
            return self.writeCommandType_enable(capabilities: capabilities)
        case .unselect:
            return self.writeCommandType_unselect()
        case .idleStart:
            return self.writeCommandType_idleStart()
        case .idleFinish:
            return self.writeCommandType_idleFinish()
        case .uid(let command):
            return self.writeCommandType_uid(command: command)
        case .copy(let sequence, let mailbox):
            return self.writeCommandType_copy(sequence: sequence, mailbox: mailbox)
        case .fetch(let set, let atts, let modifiers):
            return self.writeCommandType_fetch(set: set, atts: atts, modifiers: modifiers)
        case .store(let set, let modifiers, let flags):
            return self.writeCommandType_store(set: set, modifiers: modifiers, flags: flags)
        case .search(let returnOptions, let program):
            return self.writeCommandType_search(returnOptions: returnOptions, program: program)
        case .move(let set, let mailbox):
            return self.writeCommandType_move(set: set, mailbox: mailbox)
        case .id(let id):
            return self.writeID(id)
        case .namespace:
            return self.writeCommandType_namespace()
        }
    }
    
    private mutating func writeCommandType_capability() -> Int {
        self.writeString("CAPABILITY")
    }
    
    private mutating func writeCommandType_logout() -> Int {
        self.writeString("LOGOUT")
    }
    
    private mutating func writeCommandType_noop() -> Int {
        self.writeString("NOOP")
    }
    
    private mutating func writeCommandType_xCommand(_ command: String) -> Int {
        self.writeString("X") +
        self.writeString(command)
    }
    
    private mutating func writeCommandType_append(to: IMAPCore.Mailbox, firstMessageMetadata: IMAPCore.AppendMessage) -> Int {
        self.writeString("APPEND ") +
        self.writeMailbox(to) +
        self.writeSpace() +
        self.writeAppendMessage(firstMessageMetadata)
    }
    
    private mutating func writeCommandType_create(mailbox: IMAPCore.Mailbox, parameters: [IMAPCore.CreateParameter]) -> Int {
        self.writeString("CREATE ") +
        self.writeMailbox(mailbox) +
        self.writeCreateParameters(parameters)
    }
    
    private mutating func writeCommandType_delete(mailbox: IMAPCore.Mailbox) -> Int {
        self.writeString("DELETE ") +
        self.writeMailbox(mailbox)
    }
    
    private mutating func writeCommandType_examine(mailbox: IMAPCore.Mailbox, parameters: [IMAPCore.SelectParameter]) -> Int {
        self.writeString("EXAMINE ") +
        self.writeMailbox(mailbox) +
        self.writeIfExists(parameters) { (params) -> Int in
            self.writeSelectParameters(params)
        }
    }
    
    private mutating func writeCommandType_list(selectOptions: IMAPCore.ListSelectOptions?, mailbox: IMAPCore.Mailbox, mailboxPatterns: IMAPCore.MailboxPatterns, returnOptions: [IMAPCore.ReturnOption]) -> Int {
        self.writeString("LIST") +
        self.writeIfExists(selectOptions) { (options) -> Int in
            self.writeSpace() +
            self.writeListSelectOptions(options)
        } +
        self.writeSpace() +
        self.writeMailbox(mailbox) +
        self.writeSpace() +
        self.writeMailboxPatterns(mailboxPatterns) +
        self.writeSpace() +
        self.writeListReturnOptions(returnOptions)
    }
    
    private mutating func writeCommandType_lsub(mailbox: IMAPCore.Mailbox, listMailbox: String) -> Int {
        self.writeString("LSUB ") +
        self.writeMailbox(mailbox) +
        self.writeSpace() +
        self.writeIMAPString(listMailbox)
    }
    
    private mutating func writeCommandType_rename(from: IMAPCore.Mailbox, to: IMAPCore.Mailbox, parameters: [IMAPCore.RenameParameter]) -> Int {
        self.writeString("RENAME ") +
        self.writeMailbox(from) +
        self.writeSpace() +
        self.writeMailbox(to) +
        self.writeIfExists(parameters) { (params) -> Int in
            self.writeRenameParameters(params)
        }
    }
    
    private mutating func writeCommandType_select(mailbox: IMAPCore.Mailbox, params: [IMAPCore.SelectParameter]) -> Int {
        self.writeString("SELECT ") +
        self.writeMailbox(mailbox) +
        self.writeIfExists(params) { (params) -> Int in
            self.writeSelectParameters(params)
        }
    }
    
    private mutating func writeCommandType_status(mailbox: IMAPCore.Mailbox, attributes: [IMAPCore.StatusAttribute]) -> Int {
        self.writeString("STATUS ") +
        self.writeMailbox(mailbox) +
        self.writeString(" (") +
        self.writeStatusAttributes(attributes) +
        self.writeString(")")
    }
    
    private mutating func writeCommandType_subscribe(mailbox: IMAPCore.Mailbox) -> Int {
        self.writeString("SUBSCRIBE ") +
        self.writeMailbox(mailbox)
    }
    
    private mutating func writeCommandType_unsubscribe(mailbox: IMAPCore.Mailbox) -> Int {
        self.writeString("UNSUBSCRIBE ") +
        self.writeMailbox(mailbox)
    }
    
    private mutating func writeCommandType_authenticate(type: String, initial: IMAPCore.InitialResponse?, data: [String]) -> Int {
        self.writeString("AUTHENTICATE \(type)") +
        self.writeIfExists(initial) { (initial) -> Int in
            self.writeSpace() +
            self.writeInitialResponse(initial)
        } +
        self.writeArray(data, separator: "", parenthesis: false) { (base64, self) -> Int in
            return self.writeString("\r\n") + self.writeString(base64)
        }
    }
    
    private mutating func writeCommandType_login(userID: String, password: String) -> Int {
        self.writeString("LOGIN ") +
        self.writeUserID(userID) +
        self.writeSpace() +
        self.writeString(password)
    }
    
    private mutating func writeCommandType_startTLS() -> Int {
        self.writeString("STARTTLS")
    }
    
    private mutating func writeCommandType_check() -> Int {
        self.writeString("CHECK")
    }
    
    private mutating func writeCommandType_close() -> Int {
        self.writeString("CLOSE")
    }
    
    private mutating func writeCommandType_expunge() -> Int {
        self.writeString("EXPUNGE")
    }
    
    private mutating func writeCommandType_unselect() -> Int {
        self.writeString("UNSELECT")
    }
    
    private mutating func writeCommandType_idleStart() -> Int {
        self.writeString("IDLE")
    }
    
    private mutating func writeCommandType_idleFinish() -> Int {
        self.writeString("DONE")
    }
    
    private mutating func writeCommandType_enable(capabilities: [IMAPCore.Capability]) -> Int {
        self.writeString("ENABLE ") +
        self.writeArray(capabilities, parenthesis: false) { (element, self) in
            self.writeCapability(element)
        }
    }
    
    private mutating func writeCommandType_uid(command: IMAPCore.UIDCommandType) -> Int {
        self.writeString("UID ") +
        self.writeUIDCommandType(command)
    }
    
    private mutating func writeCommandType_copy(sequence: [IMAPCore.SequenceRange], mailbox: IMAPCore.Mailbox) -> Int {
        self.writeString("COPY ") +
        self.writeSequenceSet(sequence) +
        self.writeSpace() +
        self.writeMailbox(mailbox)
    }
    
    private mutating func writeCommandType_fetch(set: [IMAPCore.SequenceRange], atts: IMAPCore.FetchType, modifiers: [IMAPCore.FetchModifier]) -> Int {
        self.writeString("FETCH ") +
        self.writeSequenceSet(set) +
        self.writeSpace() +
        self.writeFetchType(atts) +
        self.writeIfExists(modifiers) { (modifiers) -> Int in
            self.writeFetchModifiers(modifiers)
        }
    }
    
    private mutating func writeCommandType_store(set: [IMAPCore.SequenceRange], modifiers: [IMAPCore.StoreModifier], flags: IMAPCore.StoreAttributeFlags) -> Int {
        self.writeString("STORE ") +
        self.writeSequenceSet(set) +
            self.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, self) -> Int in
            self.writeStoreModifiers(modifiers)
        } +
        self.writeSpace() +
        self.writeStoreAttributeFlags(flags)
    }
    
    private mutating func writeCommandType_search(returnOptions: [IMAPCore.SearchReturnOption], program: IMAPCore.SearchProgram) -> Int {
        self.writeString("SEARCH") +
        self.writeIfExists(returnOptions) { (options) -> Int in
            self.writeSearchReturnOptions(options)
        } +
        self.writeSpace() +
        self.writeSearchProgram(program)
    }
    
    private mutating func writeCommandType_move(set: [IMAPCore.SequenceRange], mailbox: IMAPCore.Mailbox) -> Int {
        self.writeString("MOVE ") +
        self.writeSequenceSet(set) +
        self.writeSpace() +
        self.writeMailbox(mailbox)
    }
    
    private mutating func writeCommandType_namespace() -> Int {
        self.writeNamespaceCommand()
    }

}
