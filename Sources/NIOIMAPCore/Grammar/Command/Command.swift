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

public enum Command: Equatable {
    case capability
    case logout
    case noop
    case create(MailboxName, [Parameter])
    case delete(MailboxName)
    case examine(MailboxName, [SelectParameter] = [])
    case list(ListSelectOptions? = nil, reference: MailboxName, MailboxPatterns, [ReturnOption] = [])
    case lsub(reference: MailboxName, pattern: ByteBuffer)
    case rename(from: MailboxName, to: MailboxName, params: [RenameParameter])
    case select(MailboxName, [SelectParameter] = [])
    case status(MailboxName, [MailboxAttribute])
    case subscribe(MailboxName)
    case unsubscribe(MailboxName)
    case authenticate(method: String, InitialResponse?, [ByteBuffer])
    case login(username: String, password: String)
    case starttls
    case check
    case close
    case expunge
    case enable([Capability])
    case unselect
    case idleStart
    case idleFinish
    case copy(SequenceSet, MailboxName)
    case fetch(SequenceSet, [FetchAttribute], [FetchModifier])
    case store(SequenceSet, [StoreModifier], StoreFlags)
    case search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])
    case move(SequenceSet, MailboxName)
    case id([IDParameter])
    case namespace

    case uidCopy(UIDSet, MailboxName)
    case uidMove(UIDSet, MailboxName)
    case uidFetch(UIDSet, [FetchAttribute], [FetchModifier])
    case uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])
    case uidStore(UIDSet, [StoreModifier], StoreFlags)
    case uidExpunge(UIDSet)
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeCommand(_ command: Command) -> Int {
        switch command {
        case .capability:
            return self.writeCommandKind_capability()
        case .logout:
            return self.writeCommandKind_logout()
        case .noop:
            return self.writeCommandKind_noop()
        case .create(let mailbox, let params):
            return self.writeCommandKind_create(mailbox: mailbox, parameters: params)
        case .delete(let mailbox):
            return self.writeCommandKind_delete(mailbox: mailbox)
        case .examine(let mailbox, let params):
            return self.writeCommandKind_examine(mailbox: mailbox, parameters: params)
        case .list(let selectOptions, let mailbox, let mailboxPatterns, let returnOptions):
            return self.writeCommandKind_list(selectOptions: selectOptions, mailbox: mailbox, mailboxPatterns: mailboxPatterns, returnOptions: returnOptions)
        case .lsub(let mailbox, let listMailbox):
            return self.writeCommandKind_lsub(mailbox: mailbox, listMailbox: listMailbox)
        case .rename(let from, let to, let params):
            return self.writeCommandKind_rename(from: from, to: to, parameters: params)
        case .select(let mailbox, let params):
            return self.writeCommandKind_select(mailbox: mailbox, params: params)
        case .status(let mailbox, let attributes):
            return self.writeCommandKind_status(mailbox: mailbox, attributes: attributes)
        case .subscribe(let mailbox):
            return self.writeCommandKind_subscribe(mailbox: mailbox)
        case .unsubscribe(let mailbox):
            return self.writeCommandKind_unsubscribe(mailbox: mailbox)
        case .authenticate(let method, let initial, let data):
            return self.writeCommandKind_authenticate(method: method, initial: initial, data: data)
        case .login(let userid, let password):
            return self.writeCommandKind_login(userID: userid, password: password)
        case .starttls:
            return self.writeCommandKind_startTLS()
        case .check:
            return self.writeCommandKind_check()
        case .close:
            return self.writeCommandKind_close()
        case .expunge:
            return self.writeCommandKind_expunge()
        case .uidExpunge(let set):
            return self.writeCommandKind_uidExpunge(set)
        case .enable(let capabilities):
            return self.writeCommandKind_enable(capabilities: capabilities)
        case .unselect:
            return self.writeCommandKind_unselect()
        case .idleStart:
            return self.writeCommandKind_idleStart()
        case .idleFinish:
            return self.writeCommandKind_idleFinish()
        case .copy(let set, let mailbox):
            return self.writeCommandKind_copy(set: set, mailbox: mailbox)
        case .uidCopy(let set, let mailbox):
            return self.writeCommandKind_uidCopy(set: set, mailbox: mailbox)
        case .fetch(let set, let atts, let modifiers):
            return self.writeCommandKind_fetch(set: set, atts: atts, modifiers: modifiers)
        case .uidFetch(let set, let atts, let modifiers):
            return self.writeCommandKind_uidFetch(set: set, atts: atts, modifiers: modifiers)
        case .store(let set, let modifiers, let flags):
            return self.writeCommandKind_store(set: set, modifiers: modifiers, flags: flags)
        case .uidStore(let set, let modifiers, let flags):
            return self.writeCommandKind_uidStore(set: set, modifiers: modifiers, flags: flags)
        case .search(let key, let charset, let returnOptions):
            return self.writeCommandKind_search(key: key, charset: charset, returnOptions: returnOptions)
        case .uidSearch(let key, let charset, let returnOptions):
            return self.writeCommandKind_uidSearch(key: key, charset: charset, returnOptions: returnOptions)
        case .move(let set, let mailbox):
            return self.writeCommandKind_move(set: set, mailbox: mailbox)
        case .uidMove(let set, let mailbox):
            return self.writeCommandKind_uidMove(set: set, mailbox: mailbox)
        case .id(let id):
            return self.writeCommandKind_id(id)
        case .namespace:
            return self.writeCommandKind_namespace()
        }
    }

    private mutating func writeCommandKind_capability() -> Int {
        self.writeString("CAPABILITY")
    }

    private mutating func writeCommandKind_logout() -> Int {
        self.writeString("LOGOUT")
    }

    private mutating func writeCommandKind_noop() -> Int {
        self.writeString("NOOP")
    }

    private mutating func writeCommandKind_append(to: MailboxName, firstMessageMetadata: AppendMessage) -> Int {
        self.writeString("APPEND ") +
            self.writeMailbox(to) +
            self.writeAppendMessage(firstMessageMetadata)
    }

    private mutating func writeCommandKind_create(mailbox: MailboxName, parameters: [Parameter]) -> Int {
        self.writeString("CREATE ") +
            self.writeMailbox(mailbox) +
            self.writeCreateParameters(parameters)
    }

    private mutating func writeCommandKind_delete(mailbox: MailboxName) -> Int {
        self.writeString("DELETE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_examine(mailbox: MailboxName, parameters: [SelectParameter]) -> Int {
        self.writeString("EXAMINE ") +
            self.writeMailbox(mailbox) +
            self.writeIfExists(parameters) { (params) -> Int in
                self.writeSelectParameters(params)
            }
    }

    private mutating func writeCommandKind_list(selectOptions: ListSelectOptions?, mailbox: MailboxName, mailboxPatterns: MailboxPatterns, returnOptions: [ReturnOption]) -> Int {
        self.writeString("LIST") +
            self.writeIfExists(selectOptions) { (options) -> Int in
                self.writeSpace() +
                    self.writeListSelectOptions(options)
            } +
            self.writeSpace() +
            self.writeMailbox(mailbox) +
            self.writeSpace() +
            self.writeMailboxPatterns(mailboxPatterns) +
            self.writeIfArrayHasMinimumSize(array: returnOptions, minimum: 1) { (_, self) in
                self.writeSpace() +
                    self.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_lsub(mailbox: MailboxName, listMailbox: ByteBuffer) -> Int {
        self.writeString("LSUB ") +
            self.writeMailbox(mailbox) +
            self.writeSpace() +
            self.writeIMAPString(listMailbox)
    }

    private mutating func writeCommandKind_rename(from: MailboxName, to: MailboxName, parameters: [RenameParameter]) -> Int {
        self.writeString("RENAME ") +
            self.writeMailbox(from) +
            self.writeSpace() +
            self.writeMailbox(to) +
            self.writeIfExists(parameters) { (params) -> Int in
                self.writeRenameParameters(params)
            }
    }

    private mutating func writeCommandKind_select(mailbox: MailboxName, params: [SelectParameter]) -> Int {
        self.writeString("SELECT ") +
            self.writeMailbox(mailbox) +
            self.writeIfExists(params) { (params) -> Int in
                self.writeSelectParameters(params)
            }
    }

    private mutating func writeCommandKind_status(mailbox: MailboxName, attributes: [MailboxAttribute]) -> Int {
        self.writeString("STATUS ") +
            self.writeMailbox(mailbox) +
            self.writeString(" (") +
            self.writeMailboxAttributes(attributes) +
            self.writeString(")")
    }

    private mutating func writeCommandKind_subscribe(mailbox: MailboxName) -> Int {
        self.writeString("SUBSCRIBE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_unsubscribe(mailbox: MailboxName) -> Int {
        self.writeString("UNSUBSCRIBE ") +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_authenticate(method: String, initial: InitialResponse?, data: [ByteBuffer]) -> Int {
        self.writeString("AUTHENTICATE \(method)") +
            self.writeIfExists(initial) { (initial) -> Int in
                self.writeSpace() +
                    self.writeInitialResponse(initial)
            } +
            self.writeArray(data, separator: "", parenthesis: false) { (base64, self) -> Int in
                var base64 = base64
                return self.writeString("\r\n") + self.writeBuffer(&base64)
            }
    }

    private mutating func writeCommandKind_login(userID: String, password: String) -> Int {
        self.writeString("LOGIN ") +
            self.writeIMAPString(userID) +
            self.writeSpace() +
            self.writeIMAPString(password)
    }

    private mutating func writeCommandKind_startTLS() -> Int {
        self.writeString("STARTTLS")
    }

    private mutating func writeCommandKind_check() -> Int {
        self.writeString("CHECK")
    }

    private mutating func writeCommandKind_close() -> Int {
        self.writeString("CLOSE")
    }

    private mutating func writeCommandKind_expunge() -> Int {
        self.writeString("EXPUNGE")
    }

    private mutating func writeCommandKind_uidExpunge(_ set: UIDSet) -> Int {
        self.writeString("EXPUNGE ") +
            self.writeUIDSet(set)
    }

    private mutating func writeCommandKind_unselect() -> Int {
        self.writeString("UNSELECT")
    }

    private mutating func writeCommandKind_idleStart() -> Int {
        self.writeString("IDLE")
    }

    private mutating func writeCommandKind_idleFinish() -> Int {
        self.writeString("DONE")
    }

    private mutating func writeCommandKind_enable(capabilities: [Capability]) -> Int {
        self.writeString("ENABLE ") +
            self.writeArray(capabilities, parenthesis: false) { (element, self) in
                self.writeCapability(element)
            }
    }

    private mutating func writeCommandKind_copy(set: SequenceSet, mailbox: MailboxName) -> Int {
        self.writeString("COPY ") +
            self.writeSequenceSet(set) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidCopy(set: UIDSet, mailbox: MailboxName) -> Int {
        self.writeString("UID COPY ") +
            self.writeUIDSet(set) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_fetch(set: SequenceSet, atts: [FetchAttribute], modifiers: [FetchModifier]) -> Int {
        self.writeString("FETCH ") +
            self.writeSequenceSet(set) +
            self.writeSpace() +
            self.writeFetchAttributeList(atts) +
            self.writeIfExists(modifiers) { (modifiers) -> Int in
                self.writeFetchModifiers(modifiers)
            }
    }

    private mutating func writeCommandKind_uidFetch(set: UIDSet, atts: [FetchAttribute], modifiers: [FetchModifier]) -> Int {
        self.writeString("UID FETCH ") +
            self.writeUIDSet(set) +
            self.writeSpace() +
            self.writeFetchAttributeList(atts) +
            self.writeIfExists(modifiers) { (modifiers) -> Int in
                self.writeFetchModifiers(modifiers)
            }
    }

    private mutating func writeCommandKind_store(set: SequenceSet, modifiers: [StoreModifier], flags: StoreFlags) -> Int {
        self.writeString("STORE ") +
            self.writeSequenceSet(set) +
            self.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, self) -> Int in
                self.writeStoreModifiers(modifiers)
            } +
            self.writeSpace() +
            self.writeStoreAttributeFlags(flags)
    }

    private mutating func writeCommandKind_uidStore(set: UIDSet, modifiers: [StoreModifier], flags: StoreFlags) -> Int {
        self.writeString("UID STORE ") +
            self.writeUIDSet(set) +
            self.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, self) -> Int in
                self.writeStoreModifiers(modifiers)
            } +
            self.writeSpace() +
            self.writeStoreAttributeFlags(flags)
    }

    private mutating func writeCommandKind_search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = []) -> Int {
        self.writeString("SEARCH") +
            self.writeIfExists(returnOptions) { (options) -> Int in
                self.writeSearchReturnOptions(options)
            } +
            self.writeSpace() +
            self.writeIfExists(charset) { (charset) -> Int in
                self.writeString("CHARSET \(charset) ")
            } +
            self.writeSearchKey(key)
    }

    private mutating func writeCommandKind_uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = []) -> Int {
        self.writeString("UID ") +
            self.writeCommandKind_search(key: key, charset: charset, returnOptions: returnOptions)
    }

    private mutating func writeCommandKind_move(set: SequenceSet, mailbox: MailboxName) -> Int {
        self.writeString("MOVE ") +
            self.writeSequenceSet(set) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidMove(set: UIDSet, mailbox: MailboxName) -> Int {
        self.writeString("UID MOVE ") +
            self.writeUIDSet(set) +
            self.writeSpace() +
            self.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_namespace() -> Int {
        self.writeNamespaceCommand()
    }

    @discardableResult mutating func writeCommandKind_id(_ id: [IDParameter]) -> Int {
        self.writeString("ID ") +
            self.writeIDParameters(id)
    }
}
