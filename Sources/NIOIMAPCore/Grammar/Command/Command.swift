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
    case create(MailboxName, [CreateParameter])
    case delete(MailboxName)
    case examine(MailboxName, [Parameter] = [])
    case list(ListSelectOptions?, reference: MailboxName, MailboxPatterns, [ReturnOption] = [])
    case listIndependent([ListSelectIndependentOption], reference: MailboxName, MailboxPatterns, [ReturnOption] = [])
    case lsub(reference: MailboxName, pattern: ByteBuffer)
    case rename(from: MailboxName, to: MailboxName, params: [Parameter])
    case select(MailboxName, [SelectParameter] = [])
    case status(MailboxName, [MailboxAttribute])
    case subscribe(MailboxName)
    case unsubscribe(MailboxName)
    case authenticate(method: String, initialClientResponse: InitialClientResponse?, [ByteBuffer])
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
    case fetch(SequenceSet, [FetchAttribute], [Parameter])
    case store(SequenceSet, [StoreModifier], StoreFlags)

    case search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])
    case move(SequenceSet, MailboxName)
    case id([IDParameter])
    case namespace

    case uidCopy(UIDSet, MailboxName)
    case uidMove(UIDSet, MailboxName)
    case uidFetch(UIDSet, [FetchAttribute], [Parameter])
    case uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])
    case uidStore(UIDSet, [Parameter], StoreFlags)
    case uidExpunge(UIDSet)

    case getQuota(QuotaRoot)
    case getQuotaRoot(MailboxName)
    case setQuota(QuotaRoot, [QuotaLimit])

    case getMetadata(options: [MetadataOption], mailbox: MailboxName, entries: [ByteBuffer])
    case setMetadata(mailbox: MailboxName, entries: [EntryValue])
    case esearch(ESearchOptions)

    case resetKey(mailbox: MailboxName?, mechanisms: [UAuthMechanism])
    case genURLAuth([URLRumpMechanism])

    case urlFetch([ByteBuffer])
}

// MARK: - IMAP

extension CommandEncodeBuffer {
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
        case .listIndependent(let selectOptions, let mailbox, let mailboxPatterns, let returnOptions):
            return self.writeCommandKind_listIndependent(selectOptions: selectOptions, mailbox: mailbox, mailboxPatterns: mailboxPatterns, returnOptions: returnOptions)
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
        case .authenticate(let method, let initialClientResponse, let data):
            return self.writeCommandKind_authenticate(method: method, initialClientResponse: initialClientResponse, data: data)
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
        case .getQuota(let quotaRoot):
            return self.writeCommandKind_getQuota(quotaRoot: quotaRoot)
        case .getQuotaRoot(let mailbox):
            return self.writeCommandKind_getQuotaRoot(mailbox: mailbox)
        case .setQuota(let quotaRoot, let quotaLimits):
            return self.writeCommandKind_setQuota(quotaRoot: quotaRoot, resourceLimits: quotaLimits)
        case .getMetadata(options: let options, mailbox: let mailbox, entries: let entries):
            return self.writeCommandKind_getMetadata(options: options, mailbox: mailbox, entries: entries)
        case .setMetadata(mailbox: let mailbox, entries: let entries):
            return self.writeCommandKind_setMetadata(mailbox: mailbox, entries: entries)
        case .esearch(let options):
            return self.writeCommandKind_esearch(options: options)
        case .resetKey(mailbox: let mailbox, mechanisms: let mechanisms):
            return self.writeCommandKind_resetKey(mailbox: mailbox, mechanisms: mechanisms)
        case .genURLAuth(let mechanisms):
            return self.writeCommandKind_genURLAuth(mechanisms: mechanisms)
        case .urlFetch(let urls):
            return self.writeCommandKind_urlFetch(urls: urls)
        }
    }

    private mutating func writeCommandKind_urlFetch(urls: [ByteBuffer]) -> Int {
        self.buffer.writeString("URLFETCH") +
            self.buffer.writeArray(urls, separator: "", parenthesis: false, callback: { url, buffer in
                buffer.writeSpace() +
                    buffer.writeBytes(url.readableBytesView)
            })
    }

    private mutating func writeCommandKind_genURLAuth(mechanisms: [URLRumpMechanism]) -> Int {
        self.buffer.writeString("GENURLAUTH") +
            self.buffer.writeArray(mechanisms, separator: "", parenthesis: false, callback: { mechanism, buffer in
                buffer.writeSpace() +
                buffer.writeURLRumpMechanism(mechanism)
            })
    }

    private mutating func writeCommandKind_resetKey(mailbox: MailboxName?, mechanisms: [UAuthMechanism]) -> Int {
        self.buffer.writeString("RESETKEY") +
            self.buffer.writeIfExists(mailbox, callback: { mailbox in
                self.buffer.writeSpace() +
                    self.buffer.writeMailbox(mailbox) +

                    // disable the array separator as we need a space before the first one too (if it exists)
                    self.buffer.writeArray(mechanisms, separator: "", parenthesis: false, callback: { mechanism, buffer in
                        buffer.writeSpace() +
                            buffer.writeUAuthMechanism(mechanism)
                    })
            })
    }

    private mutating func writeCommandKind_getMetadata(options: [MetadataOption], mailbox: MailboxName, entries: [ByteBuffer]) -> Int {
        self.buffer.writeString("GETMETADATA") +
            self.buffer.writeIfArrayHasMinimumSize(array: options, callback: { array, buffer in
                buffer.writeSpace() + buffer.writeMetadataOptions(array)
            }) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeEntries(entries)
    }

    private mutating func writeCommandKind_setMetadata(mailbox: MailboxName, entries: [EntryValue]) -> Int {
        self.buffer.writeString("SETMETADATA ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeEntryValues(entries)
    }

    private mutating func writeCommandKind_capability() -> Int {
        self.buffer.writeString("CAPABILITY")
    }

    private mutating func writeCommandKind_logout() -> Int {
        self.buffer.writeString("LOGOUT")
    }

    private mutating func writeCommandKind_noop() -> Int {
        self.buffer.writeString("NOOP")
    }

    private mutating func writeCommandKind_create(mailbox: MailboxName, parameters: [CreateParameter]) -> Int {
        self.buffer.writeString("CREATE ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeArray(parameters, separator: "", parenthesis: false) { (param, buffer) -> Int in
                buffer.writeCreateParameter(param)
            }
    }

    private mutating func writeCommandKind_delete(mailbox: MailboxName) -> Int {
        self.buffer.writeString("DELETE ") +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_examine(mailbox: MailboxName, parameters: [Parameter]) -> Int {
        self.buffer.writeString("EXAMINE ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeIfExists(parameters) { (params) -> Int in
                self.buffer.writeParameters(params)
            }
    }

    private mutating func writeCommandKind_list(selectOptions: ListSelectOptions?, mailbox: MailboxName, mailboxPatterns: MailboxPatterns, returnOptions: [ReturnOption]) -> Int {
        self.buffer.writeString("LIST") +
            self.buffer.writeIfExists(selectOptions) { (options) -> Int in
                self.buffer.writeSpace() +
                    self.buffer.writeListSelectOptions(options)
            } +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeMailboxPatterns(mailboxPatterns) +
            self.buffer.writeIfArrayHasMinimumSize(array: returnOptions, minimum: 1) { (_, buffer) in
                buffer.writeSpace() +
                    buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_listIndependent(selectOptions: [ListSelectIndependentOption], mailbox: MailboxName, mailboxPatterns: MailboxPatterns, returnOptions: [ReturnOption]) -> Int {
        self.buffer.writeString("LIST") +
            self.buffer.writeIfArrayHasMinimumSize(array: selectOptions, callback: { array, buffer in
                buffer.writeArray(array) { element, buffer in
                    buffer.writeListSelectIndependentOption(element)
                }
            }) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeMailboxPatterns(mailboxPatterns) +
            self.buffer.writeIfArrayHasMinimumSize(array: returnOptions, minimum: 1) { (_, buffer) in
                buffer.writeSpace() +
                    buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_lsub(mailbox: MailboxName, listMailbox: ByteBuffer) -> Int {
        self.buffer.writeString("LSUB ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeIMAPString(listMailbox)
    }

    private mutating func writeCommandKind_rename(from: MailboxName, to: MailboxName, parameters: [Parameter]) -> Int {
        self.buffer.writeString("RENAME ") +
            self.buffer.writeMailbox(from) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(to) +
            self.buffer.writeIfExists(parameters) { (params) -> Int in
                self.buffer.writeParameters(params)
            }
    }

    private mutating func writeCommandKind_select(mailbox: MailboxName, params: [SelectParameter]) -> Int {
        self.buffer.writeString("SELECT ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeArray(params, callback: { (element, buffer) -> Int in
                buffer.writeSelectParameter(element)
                })
    }

    private mutating func writeCommandKind_status(mailbox: MailboxName, attributes: [MailboxAttribute]) -> Int {
        self.buffer.writeString("STATUS ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeString(" (") +
            self.buffer.writeMailboxAttributes(attributes) +
            self.buffer.writeString(")")
    }

    private mutating func writeCommandKind_subscribe(mailbox: MailboxName) -> Int {
        self.buffer.writeString("SUBSCRIBE ") +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_unsubscribe(mailbox: MailboxName) -> Int {
        self.buffer.writeString("UNSUBSCRIBE ") +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_authenticate(method: String, initialClientResponse: InitialClientResponse?, data: [ByteBuffer]) -> Int {
        self.buffer.writeString("AUTHENTICATE \(method)") +
            self.buffer.writeIfExists(initialClientResponse, callback: { resp in
                self.buffer.writeSpace() +
                    self.buffer.writeInitialClientResponse(resp)
            }) +
            self.buffer.writeArray(data, separator: "", parenthesis: false) { (buffer, self) -> Int in
                self.writeString("\r\n") + self.writeBufferAsBase64(buffer)
            }
    }

    private mutating func writeCommandKind_login(userID: String, password: String) -> Int {
        self.buffer.writeString("LOGIN ") +
            self.buffer.writeIMAPString(userID) +
            self.buffer.writeSpace() +
            self.buffer.writeIMAPString(password)
    }

    private mutating func writeCommandKind_startTLS() -> Int {
        self.buffer.writeString("STARTTLS")
    }

    private mutating func writeCommandKind_check() -> Int {
        self.buffer.writeString("CHECK")
    }

    private mutating func writeCommandKind_close() -> Int {
        self.buffer.writeString("CLOSE")
    }

    private mutating func writeCommandKind_expunge() -> Int {
        self.buffer.writeString("EXPUNGE")
    }

    private mutating func writeCommandKind_uidExpunge(_ set: UIDSet) -> Int {
        self.buffer.writeString("EXPUNGE ") +
            self.buffer.writeUIDSet(set)
    }

    private mutating func writeCommandKind_unselect() -> Int {
        self.buffer.writeString("UNSELECT")
    }

    private mutating func writeCommandKind_idleStart() -> Int {
        self.buffer.writeString("IDLE")
    }

    private mutating func writeCommandKind_idleFinish() -> Int {
        self.buffer.writeString("DONE")
    }

    private mutating func writeCommandKind_enable(capabilities: [Capability]) -> Int {
        self.buffer.writeString("ENABLE ") +
            self.buffer.writeArray(capabilities, parenthesis: false) { (element, self) in
                self.writeCapability(element)
            }
    }

    private mutating func writeCommandKind_copy(set: SequenceSet, mailbox: MailboxName) -> Int {
        self.buffer.writeString("COPY ") +
            self.buffer.writeSequenceSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidCopy(set: UIDSet, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID COPY ") +
            self.buffer.writeUIDSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_fetch(set: SequenceSet, atts: [FetchAttribute], modifiers: [Parameter]) -> Int {
        self.buffer.writeString("FETCH ") +
            self.buffer.writeSequenceSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeFetchAttributeList(atts) +
            self.buffer.writeIfExists(modifiers) { (modifiers) -> Int in
                self.buffer.writeParameters(modifiers)
            }
    }

    private mutating func writeCommandKind_uidFetch(set: UIDSet, atts: [FetchAttribute], modifiers: [Parameter]) -> Int {
        self.buffer.writeString("UID FETCH ") +
            self.buffer.writeUIDSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeFetchAttributeList(atts) +
            self.buffer.writeIfExists(modifiers) { (modifiers) -> Int in
                self.buffer.writeParameters(modifiers)
            }
    }

    private mutating func writeCommandKind_store(set: SequenceSet, modifiers: [StoreModifier], flags: StoreFlags) -> Int {
        self.buffer.writeString("STORE ") +
            self.buffer.writeSequenceSet(set) +
            self.buffer.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, buffer) -> Int in
                buffer.writeSpace() +
                    buffer.writeArray(modifiers) { (element, buffer) -> Int in
                        buffer.writeStoreModifier(element)
                    }
            } +
            self.buffer.writeSpace() +
            self.buffer.writeStoreAttributeFlags(flags)
    }

    private mutating func writeCommandKind_uidStore(set: UIDSet, modifiers: [Parameter], flags: StoreFlags) -> Int {
        self.buffer.writeString("UID STORE ") +
            self.buffer.writeUIDSet(set) +
            self.buffer.writeIfArrayHasMinimumSize(array: modifiers) { (modifiers, buffer) -> Int in
                buffer.writeParameters(modifiers)
            } +
            self.buffer.writeSpace() +
            self.buffer.writeStoreAttributeFlags(flags)
    }

    private mutating func writeCommandKind_search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = []) -> Int {
        self.buffer.writeString("SEARCH") +
            self.buffer.writeIfExists(returnOptions) { (options) -> Int in
                self.buffer.writeSearchReturnOptions(options)
            } +
            self.buffer.writeSpace() +
            self.buffer.writeIfExists(charset) { (charset) -> Int in
                self.buffer.writeString("CHARSET \(charset) ")
            } +
            self.buffer.writeSearchKey(key)
    }

    private mutating func writeCommandKind_uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = []) -> Int {
        self.buffer.writeString("UID ") +
            self.writeCommandKind_search(key: key, charset: charset, returnOptions: returnOptions)
    }

    private mutating func writeCommandKind_move(set: SequenceSet, mailbox: MailboxName) -> Int {
        self.buffer.writeString("MOVE ") +
            self.buffer.writeSequenceSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidMove(set: UIDSet, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID MOVE ") +
            self.buffer.writeUIDSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_namespace() -> Int {
        self.buffer.writeNamespaceCommand()
    }

    @discardableResult mutating func writeCommandKind_id(_ id: [IDParameter]) -> Int {
        self.buffer.writeString("ID ") +
            self.buffer.writeIDParameters(id)
    }

    private mutating func writeCommandKind_getQuota(quotaRoot: QuotaRoot) -> Int {
        self.buffer.writeString("GETQUOTA ") +
            self.buffer.writeQuotaRoot(quotaRoot)
    }

    private mutating func writeCommandKind_getQuotaRoot(mailbox: MailboxName) -> Int {
        self.buffer.writeString("GETQUOTAROOT ") +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_setQuota(quotaRoot: QuotaRoot, resourceLimits: [QuotaLimit]) -> Int {
        self.buffer.writeString("SETQUOTA ") +
            self.buffer.writeQuotaRoot(quotaRoot) +
            self.buffer.writeSpace() +
            self.buffer.writeArray(resourceLimits, callback: { (limit, self) in
                self.writeQuotaLimit(limit)
            })
    }

    private mutating func writeCommandKind_esearch(options: ESearchOptions) -> Int {
        self.buffer.writeString("ESEARCH") +
            self.buffer.writeESearchOptions(options)
    }
}
