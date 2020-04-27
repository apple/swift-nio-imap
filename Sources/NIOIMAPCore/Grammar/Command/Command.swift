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

extension NIOIMAP {
    public enum Command: Equatable {
        case capability
        case logout
        case noop
        case append(to: MailboxName, firstMessageMetadata: AppendMessage)
        case create(MailboxName, [CreateParameter])
        case delete(MailboxName)
        case examine(MailboxName, [SelectParameter])
        case list(ListSelectOptions?, MailboxName, MailboxPatterns, [NIOIMAP.ReturnOption])
        case lsub(MailboxName, ByteBuffer)
        case rename(from: MailboxName, to: MailboxName, params: [RenameParameter])
        case select(MailboxName, [SelectParameter])
        case status(MailboxName, [StatusAttribute])
        case subscribe(MailboxName)
        case unsubscribe(MailboxName)
        case authenticate(String, InitialResponse?, [ByteBuffer])
        case login(String, String)
        case starttls
        case check
        case close
        case expunge
        case enable([Capability])
        case unselect
        case idleStart
        case idleFinish
        case copy([NIOIMAP.SequenceRange], MailboxName)
        case fetch([NIOIMAP.SequenceRange], FetchType, [FetchModifier])
        case store([NIOIMAP.SequenceRange], [StoreModifier], StoreAttributeFlags)
        case search(returnOptions: [SearchReturnOption], program: SearchProgram)
        case move([NIOIMAP.SequenceRange], MailboxName)
        case id([IDParameter])
        case namespace

        case uidCopy([NIOIMAP.SequenceRange], MailboxName)
        case uidMove([NIOIMAP.SequenceRange], MailboxName)
        case uidFetch([NIOIMAP.SequenceRange], FetchType, [FetchModifier])
        case uidSearch(returnOptions: [SearchReturnOption], program: SearchProgram)
        case uidStore([NIOIMAP.SequenceRange], [StoreModifier], StoreAttributeFlags)
        case uidExpunge([NIOIMAP.SequenceRange])
    }
}

// MARK: - IMAP

extension ByteBuffer {
    @discardableResult mutating func writeCommandType(_ commandType: NIOIMAP.Command) -> Int {
        switch commandType {
        case .capability:
            return self.writeCommandType_capability()
        case .logout:
            return self.writeCommandType_logout()
        case .noop:
            return self.writeCommandType_noop()
        case .append(let to, let firstMessageMetadata):
            return self.writeCommandType_append(to: to, firstMessageMetadata: firstMessageMetadata)
        case .create(let mailbox, let params):
            return self.writeCommandType_create(mailbox: mailbox, parameters: params)
        case .delete(let mailbox):
            return self.writeCommandType_delete(mailbox: mailbox)
        case .examine(let mailbox, let params):
            return self.writeCommandType_examine(mailbox: mailbox, parameters: params)
        case .list(let selectOptions, let mailbox, let mailboxPatterns, let returnOptions):
            return self.writeCommandType_list(selectOptions: selectOptions, mailbox: mailbox, mailboxPatterns: mailboxPatterns, returnOptions: returnOptions)
        case .lsub(let mailbox, let listMailbox):
            return self.writeCommandType_lsub(mailbox: mailbox, listMailbox: listMailbox)
        case .rename(let from, let to, let params):
            return self.writeCommandType_rename(from: from, to: to, parameters: params)
        case .select(let mailbox, let params):
            return self.writeCommandType_select(mailbox: mailbox, params: params)
        case .status(let mailbox, let attributes):
            return self.writeCommandType_status(mailbox: mailbox, attributes: attributes)
        case .subscribe(let mailbox):
            return self.writeCommandType_subscribe(mailbox: mailbox)
        case .unsubscribe(let mailbox):
            return self.writeCommandType_unsubscribe(mailbox: mailbox)
        case .authenticate(let type, let initial, let data):
            return self.writeCommandType_authenticate(type: type, initial: initial, data: data)
        case .login(let userid, let password):
            return self.writeCommandType_login(userID: userid, password: password)
        case .starttls:
            return self.writeCommandType_startTLS()
        case .check:
            return self.writeCommandType_check()
        case .close:
            return self.writeCommandType_close()
        case .expunge:
            return self.writeCommandType_expunge()
        case .uidExpunge(let set):
            return self.writeCommandType_uidExpunge(set)
        case .enable(let capabilities):
            return self.writeCommandType_enable(capabilities: capabilities)
        case .unselect:
            return self.writeCommandType_unselect()
        case .idleStart:
            return self.writeCommandType_idleStart()
        case .idleFinish:
            return self.writeCommandType_idleFinish()
        case .copy(let sequence, let mailbox):
            return self.writeCommandType_copy(sequence: sequence, mailbox: mailbox)
        case .uidCopy(let sequence, let mailbox):
            return self.writeCommandType_uidCopy(sequence: sequence, mailbox: mailbox)
        case .fetch(let set, let atts, let modifiers):
            return self.writeCommandType_fetch(set: set, atts: atts, modifiers: modifiers)
        case .uidFetch(let set, let atts, let modifiers):
            return self.writeCommandType_uidFetch(set: set, atts: atts, modifiers: modifiers)
        case .store(let set, let modifiers, let flags):
            return self.writeCommandType_store(set: set, modifiers: modifiers, flags: flags)
        case .uidStore(let set, let modifiers, let flags):
            return self.writeCommandType_uidStore(set: set, modifiers: modifiers, flags: flags)
        case .search(let returnOptions, let program):
            return self.writeCommandType_search(returnOptions: returnOptions, program: program)
        case .uidSearch(returnOptions: let returnOptions, program: let program):
            return self.writeCommandType_uidSearch(returnOptions: returnOptions, program: program)
        case .move(let set, let mailbox):
            return self.writeCommandType_move(set: set, mailbox: mailbox)
        case .uidMove(let set, let mailbox):
            return self.writeCommandType_uidMove(set: set, mailbox: mailbox)
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

    private mutating func writeCommandType_append(to: NIOIMAP.MailboxName, firstMessageMetadata: NIOIMAP.AppendMessage) -> Int {
        self.writeString("APPEND ") +
            self.writeMailbox(to) +
            self.writeSpace() +
            self.writeAppendMessage(firstMessageMetadata)
    }

    private mutating func writeCommandType_create(mailbox: NIOIMAP.MailboxName, parameters: [NIOIMAP.CreateParameter]) -> Int {
        self.writeString("CREATE ") +
            self.writeMailbox(mailbox) +
            self.writeCreateParameters(parameters)
    }

    private mutating func writeCommandType_delete(mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("DELETE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandType_examine(mailbox: NIOIMAP.MailboxName, parameters: [NIOIMAP.SelectParameter]) -> Int {
        self.writeString("EXAMINE ") +
            self.writeMailbox(mailbox) +
            self.writeIfExists(parameters) { (params) -> Int in
                self.writeSelectParameters(params)
            }
    }

    private mutating func writeCommandType_list(selectOptions: NIOIMAP.ListSelectOptions?, mailbox: NIOIMAP.MailboxName, mailboxPatterns: NIOIMAP.MailboxPatterns, returnOptions: [NIOIMAP.ReturnOption]) -> Int {
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

    private mutating func writeCommandType_lsub(mailbox: NIOIMAP.MailboxName, listMailbox: ByteBuffer) -> Int {
        self.writeString("LSUB ") +
            self.writeMailbox(mailbox) +
            self.writeSpace() +
            self.writeIMAPString(listMailbox)
    }

    private mutating func writeCommandType_rename(from: NIOIMAP.MailboxName, to: NIOIMAP.MailboxName, parameters: [NIOIMAP.RenameParameter]) -> Int {
        self.writeString("RENAME ") +
            self.writeMailbox(from) +
            self.writeSpace() +
            self.writeMailbox(to) +
            self.writeIfExists(parameters) { (params) -> Int in
                self.writeRenameParameters(params)
            }
    }

    private mutating func writeCommandType_select(mailbox: NIOIMAP.MailboxName, params: [NIOIMAP.SelectParameter]) -> Int {
        self.writeString("SELECT ") +
            self.writeMailbox(mailbox) +
            self.writeIfExists(params) { (params) -> Int in
                self.writeSelectParameters(params)
            }
    }

    private mutating func writeCommandType_status(mailbox: NIOIMAP.MailboxName, attributes: [NIOIMAP.StatusAttribute]) -> Int {
        self.writeString("STATUS ") +
            self.writeMailbox(mailbox) +
            self.writeString(" (") +
            self.writeStatusAttributes(attributes) +
            self.writeString(")")
    }

    private mutating func writeCommandType_subscribe(mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("SUBSCRIBE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandType_unsubscribe(mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("UNSUBSCRIBE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandType_authenticate(type: String, initial: NIOIMAP.InitialResponse?, data: [ByteBuffer]) -> Int {
        self.writeString("AUTHENTICATE \(type)") +
            self.writeIfExists(initial) { (initial) -> Int in
                self.writeSpace() +
                    self.writeInitialResponse(initial)
            } +
            self.writeArray(data, separator: "", parenthesis: false) { (base64, self) -> Int in
                var base64 = base64
                return self.writeString("\r\n") + self.writeBuffer(&base64)
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

    private mutating func writeCommandType_uidExpunge(_ set: [NIOIMAP.SequenceRange]) -> Int {
        self.writeString("EXPUNGE ") +
            self.writeSequenceSet(set)
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

    private mutating func writeCommandType_enable(capabilities: [NIOIMAP.Capability]) -> Int {
        self.writeString("ENABLE ") +
            self.writeArray(capabilities, parenthesis: false) { (element, self) in
                self.writeCapability(element)
            }
    }

    private mutating func writeCommandType_copy(sequence: [NIOIMAP.SequenceRange], mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("COPY ") +
            self.writeSequenceSet(sequence) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandType_uidCopy(sequence: [NIOIMAP.SequenceRange], mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("UID ") +
            self.writeCommandType_copy(sequence: sequence, mailbox: mailbox)
    }

    private mutating func writeCommandType_fetch(set: [NIOIMAP.SequenceRange], atts: NIOIMAP.FetchType, modifiers: [NIOIMAP.FetchModifier]) -> Int {
        self.writeString("FETCH ") +
            self.writeSequenceSet(set) +
            self.writeSpace() +
            self.writeFetchType(atts) +
            self.writeIfExists(modifiers) { (modifiers) -> Int in
                self.writeFetchModifiers(modifiers)
            }
    }

    private mutating func writeCommandType_uidFetch(set: [NIOIMAP.SequenceRange], atts: NIOIMAP.FetchType, modifiers: [NIOIMAP.FetchModifier]) -> Int {
        self.writeString("UID ") +
            self.writeCommandType_fetch(set: set, atts: atts, modifiers: modifiers)
    }

    private mutating func writeCommandType_store(set: [NIOIMAP.SequenceRange], modifiers: [NIOIMAP.StoreModifier], flags: NIOIMAP.StoreAttributeFlags) -> Int {
        self.writeString("STORE ") +
            self.writeSequenceSet(set) +
            self.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, self) -> Int in
                self.writeStoreModifiers(modifiers)
            } +
            self.writeSpace() +
            self.writeStoreAttributeFlags(flags)
    }

    private mutating func writeCommandType_uidStore(set: [NIOIMAP.SequenceRange], modifiers: [NIOIMAP.StoreModifier], flags: NIOIMAP.StoreAttributeFlags) -> Int {
        self.writeString("UID ") +
            self.writeCommandType_store(set: set, modifiers: modifiers, flags: flags)
    }

    private mutating func writeCommandType_search(returnOptions: [NIOIMAP.SearchReturnOption], program: NIOIMAP.SearchProgram) -> Int {
        self.writeString("SEARCH") +
            self.writeIfExists(returnOptions) { (options) -> Int in
                self.writeSearchReturnOptions(options)
            } +
            self.writeSpace() +
            self.writeSearchProgram(program)
    }

    private mutating func writeCommandType_uidSearch(returnOptions: [NIOIMAP.SearchReturnOption], program: NIOIMAP.SearchProgram) -> Int {
        self.writeString("UID ") +
            self.writeCommandType_search(returnOptions: returnOptions, program: program)
    }

    private mutating func writeCommandType_move(set: [NIOIMAP.SequenceRange], mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("MOVE ") +
            self.writeSequenceSet(set) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandType_uidMove(set: [NIOIMAP.SequenceRange], mailbox: NIOIMAP.MailboxName) -> Int {
        self.writeString("UID ") +
            self.writeCommandType_move(set: set, mailbox: mailbox)
    }

    private mutating func writeCommandType_namespace() -> Int {
        self.writeNamespaceCommand()
    }
}
