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
import struct OrderedCollections.OrderedDictionary

/// Commands are sent by clients, and processed by servers.
///
/// A notably exclusion here is the ability to append a message.
/// This is handled separately using the `AppendCommand` type,
/// as a state is maintained to enable streaming of large amounts
/// of data.
public enum Command: Equatable {
    /// Requests a server's capabilities.
    case capability

    /// Returns the session's state to "non-authenticated".
    case logout

    /// Performs no operation, typically used to test that a server is responding to commands.
    case noop

    /// Creates a new mailbox.
    case create(MailboxName, [CreateParameter])

    /// Deletes a mailbox.
    case delete(MailboxName)

    /// Similar to `.select` and returns the same data, however the current mailbox is identified as readonly
    case examine(MailboxName, [SelectParameter] = [])

    /// Returns a subset of names from the complete set of all names available to the client.
    case list(ListSelectOptions?, reference: MailboxName, MailboxPatterns, [ReturnOption] = [])

    /// Similar to `.list`, but uses options that do not syntactically interact with other options
    case listIndependent([ListSelectIndependentOption], reference: MailboxName, MailboxPatterns, [ReturnOption] = [])

    /// Returns a subset of names from the complete set of names that the user has marked as "active" or "subscribed"
    case lsub(reference: MailboxName, pattern: ByteBuffer)

    /// Renames the given mailbox.
    case rename(from: MailboxName, to: MailboxName, parameters: OrderedDictionary<String, ParameterValue?>)

    /// Selects the given mailbox in preparation of running more commands.
    case select(MailboxName, [SelectParameter] = [])

    /// Retrieves the status of the given mailbox.
    case status(MailboxName, [MailboxAttribute])

    /// Subscribes to the given mailbox.
    case subscribe(MailboxName)

    /// Unsubscribes from the given mailbox.
    case unsubscribe(MailboxName)

    /// Begins the process of the client authenticating against the server. The client specifies a authentication `mechanism`, and the server may respond
    /// with one or more challenges, which the client is also required to respond to using `CommandStreamPart.continuationResponse`.
    case authenticate(mechanism: AuthenticationMechanism, initialResponse: InitialResponse?)

    /// Authenticates the client using a username and password
    case login(username: String, password: String)

    /// Begins TLS negotiation immediately after this command is sent.
    case startTLS

    /// Requests a check-point of the server's in-memory representation of the mailbox. Allows the server to do some housekeeping.
    case check

    /// Permanently deletes all messages in the selected mailbox that have the *\Deleted* flag set, and unselects the mailbox.
    case close

    /// Permanently deletes all messages in the selected mailbox that have the *\Deleted* flag set.
    case expunge

    /// Enables each listed capability, providing the server has advertised support for those capabilities.
    case enable([Capability])

    /// Unselects the currently-select mailbox, and returns to an unselected state.
    case unselect

    /// Moves the server into an idle state. The server may send periodic reminder that it's idle. No more commands may be sent until
    /// `CommandStreamPart.idleDone` has been sent.
    case idleStart

    /// Copies each message in a given set to a new mailbox, preserving the original in the current mailbox.
    case copy(LastCommandSet<SequenceRangeSet>, MailboxName)

    /// Fetches an array of specified attributes for each message in a given set.
    case fetch(LastCommandSet<SequenceRangeSet>, [FetchAttribute], OrderedDictionary<String, ParameterValue?>)

    /// Alters data associated with a message, typically returning the new data as an untagged fetch response.
    case store(LastCommandSet<SequenceRangeSet>, [StoreModifier], StoreData)

    /// Searches the currently-selected mailbox for messages that match the search criteria.
    case search(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])

    /// Moves each message in a given set into a new mailbox, removing the copy from the current mailbox.
    case move(LastCommandSet<SequenceRangeSet>, MailboxName)

    /// Identifies the client to the server
    case id(OrderedDictionary<String, String?>)

    /// Retrieves the namespaces available to the user.
    case namespace

    /// Similar to `.copy`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidCopy(LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, MailboxName)

    /// Similar to `.move`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidMove(LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, MailboxName)

    /// Similar to `.fetch`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidFetch(LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, [FetchAttribute], OrderedDictionary<String, ParameterValue?>)

    /// Similar to `.search`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidSearch(key: SearchKey, charset: String? = nil, returnOptions: [SearchReturnOption] = [])

    /// Similar to `.store`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidStore(LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, OrderedDictionary<String, ParameterValue?>, StoreData)

    /// Similar to `.expunge`, but uses unique identifier instead of sequence numbers to identify messages.
    case uidExpunge(LastCommandSet<MessageIdentifierSetNonEmpty<UID>>)

    /// Takes the name of a quota root and returns the quota root's resource usage and limits.
    case getQuota(QuotaRoot)

    /// Takes the name of a mailbox and returns the list of quota roots for the mailbox in an untagged QUOTAROOT response.
    case getQuotaRoot(MailboxName)

    /// Sets the resource limits for a given quote root.
    case setQuota(QuotaRoot, [QuotaLimit])

    /// When the mailbox name is the empty string, this command retrieves
    /// server annotations.  When the mailbox name is not empty, this command
    /// retrieves annotations on the specified mailbox.
    case getMetadata(options: [MetadataOption], mailbox: MailboxName, entries: [MetadataEntryName])

    /// Sets the specified list of entries by adding or
    /// replacing the specified values provided, on the specified existing
    /// mailboxes or on the server (if the mailbox argument is the empty
    /// string).
    case setMetadata(mailbox: MailboxName, entries: OrderedDictionary<MetadataEntryName, MetadataValue>)

    /// Performs an extended search as defined in RFC 4731.
    case extendedSearch(ExtendedSearchOptions)

    /// When sent with no arguments: removes all mailbox access keys
    /// in the user's mailbox access key table, revoking all URLs currently
    /// authorized using URLAUTH by the user.
    /// When sent with arguments: generates a
    /// new mailbox access key for the given mailbox in the user's mailbox
    /// access key table, replacing any previous mailbox access key (and
    /// revoking any URLs that were authorized with a URLAUTH using that key)
    /// in that table.
    case resetKey(mailbox: MailboxName?, mechanisms: [URLAuthenticationMechanism])

    /// Requests that the server generate a URLAUTH-
    /// authorized URL for each of the given URLs using the given URL
    /// authorization mechanism.
    case generateAuthorizedURL([RumpURLAndMechanism])

    /// Requests that the server return the text data
    /// associated with the specified IMAP URLs
    case urlFetch([ByteBuffer])

    /// Instructs the server to use the named compression mechanism.
    case compress(Capability.CompressionKind)
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
            return self.writeCommandKind_select(mailbox: mailbox, parameters: params)
        case .status(let mailbox, let attributes):
            return self.writeCommandKind_status(mailbox: mailbox, attributes: attributes)
        case .subscribe(let mailbox):
            return self.writeCommandKind_subscribe(mailbox: mailbox)
        case .unsubscribe(let mailbox):
            return self.writeCommandKind_unsubscribe(mailbox: mailbox)
        case .authenticate(let mechanism, let initialResponse):
            return self.writeCommandKind_authenticate(mechanism: mechanism, initialResponse: initialResponse)
        case .login(let userid, let password):
            return self.writeCommandKind_login(userID: userid, password: password)
        case .startTLS:
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
        case .copy(let set, let mailbox):
            return self.writeCommandKind_copy(set: set, mailbox: mailbox)
        case .uidCopy(let set, let mailbox):
            return self.writeCommandKind_uidCopy(set: set, mailbox: mailbox)
        case .fetch(let set, let atts, let modifiers):
            return self.writeCommandKind_fetch(set: set, atts: atts, modifiers: modifiers)
        case .uidFetch(let set, let atts, let modifiers):
            return self.writeCommandKind_uidFetch(set: set, atts: atts, modifiers: modifiers)
        case .store(let set, let modifiers, let data):
            return self.writeCommandKind_store(set: set, modifiers: modifiers, data: data)
        case .uidStore(let set, let modifiers, let data):
            return self.writeCommandKind_uidStore(set: set, modifiers: modifiers, data: data)
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
        case .extendedSearch(let options):
            return self.writeCommandKind_extendedSearch(options: options)
        case .resetKey(mailbox: let mailbox, mechanisms: let mechanisms):
            return self.writeCommandKind_resetKey(mailbox: mailbox, mechanisms: mechanisms)
        case .generateAuthorizedURL(let mechanisms):
            return self.writeCommandKind_generateAuthorizedURL(mechanisms: mechanisms)
        case .urlFetch(let urls):
            return self.writeCommandKind_urlFetch(urls: urls)
        case .compress(let kind):
            return self.writeCommandKind_compress(kind: kind)
        }
    }

    private mutating func writeCommandKind_urlFetch(urls: [ByteBuffer]) -> Int {
        self.buffer.writeString("URLFETCH") +
            self.buffer.writeArray(urls, prefix: " ", parenthesis: false) { url, buffer in
                buffer.writeBytes(url.readableBytesView)
            }
    }

    private mutating func writeCommandKind_generateAuthorizedURL(mechanisms: [RumpURLAndMechanism]) -> Int {
        self.buffer.writeString("GENURLAUTH") +
            self.buffer.writeArray(mechanisms, prefix: " ", parenthesis: false) { mechanism, buffer in
                buffer.writeURLRumpMechanism(mechanism)
            }
    }

    private mutating func writeCommandKind_resetKey(mailbox: MailboxName?, mechanisms: [URLAuthenticationMechanism]) -> Int {
        self.buffer.writeString("RESETKEY") +
            self.buffer.writeIfExists(mailbox) { mailbox in
                self.buffer.writeSpace() +
                    self.buffer.writeMailbox(mailbox) +

                    self.buffer.writeArray(mechanisms, prefix: " ", parenthesis: false) { mechanism, buffer in
                        buffer.writeURLAuthenticationMechanism(mechanism)
                    }
            }
    }

    private mutating func writeCommandKind_getMetadata(options: [MetadataOption], mailbox: MailboxName, entries: [MetadataEntryName]) -> Int {
        self.buffer.writeString("GETMETADATA") +
            self.buffer.write(if: options.count >= 1) {
                buffer.writeSpace() + buffer.writeMetadataOptions(options)
            } +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeEntries(entries)
    }

    private mutating func writeCommandKind_setMetadata(mailbox: MailboxName, entries: OrderedDictionary<MetadataEntryName, MetadataValue>) -> Int {
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
            self.buffer.write(if: parameters.count > 0) {
                self.buffer.writeSpace() +
                    self.buffer.writeArray(parameters, separator: "", parenthesis: true) { (param, buffer) -> Int in
                        buffer.writeCreateParameter(param)
                    }
            }
    }

    private mutating func writeCommandKind_delete(mailbox: MailboxName) -> Int {
        self.buffer.writeString("DELETE ") +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_examine(mailbox: MailboxName, parameters: [SelectParameter]) -> Int {
        self.buffer.writeString("EXAMINE ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSelectParameters(parameters)
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
            self.buffer.write(if: returnOptions.count >= 1) {
                self.buffer.writeSpace() +
                    self.buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_listIndependent(selectOptions: [ListSelectIndependentOption], mailbox: MailboxName, mailboxPatterns: MailboxPatterns, returnOptions: [ReturnOption]) -> Int {
        self.buffer.writeString("LIST") +
            self.buffer.write(if: selectOptions.count >= 1) {
                self.buffer.writeArray(selectOptions) { element, buffer in
                    buffer.writeListSelectIndependentOption(element)
                }
            } +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeMailboxPatterns(mailboxPatterns) +
            self.buffer.write(if: returnOptions.count >= 1) {
                self.buffer.writeSpace() +
                    self.buffer.writeListReturnOptions(returnOptions)
            }
    }

    private mutating func writeCommandKind_lsub(mailbox: MailboxName, listMailbox: ByteBuffer) -> Int {
        self.buffer.writeString("LSUB ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSpace() +
            self.buffer.writeIMAPString(listMailbox)
    }

    private mutating func writeCommandKind_rename(from: MailboxName, to: MailboxName, parameters: OrderedDictionary<String, ParameterValue?>) -> Int {
        self.buffer.writeString("RENAME ") +
            self.buffer.writeMailbox(from) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(to) +
            self.buffer.writeIfExists(parameters) { (params) -> Int in
                self.buffer.writeParameters(params)
            }
    }

    private mutating func writeCommandKind_select(mailbox: MailboxName, parameters: [SelectParameter]) -> Int {
        self.buffer.writeString("SELECT ") +
            self.buffer.writeMailbox(mailbox) +
            self.buffer.writeSelectParameters(parameters)
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

    private mutating func writeCommandKind_compress(kind: Capability.CompressionKind) -> Int {
        self.buffer.writeString("COMPRESS \(kind.rawValue)")
    }

    private mutating func writeCommandKind_authenticate(mechanism: AuthenticationMechanism, initialResponse: InitialResponse?) -> Int {
        self.buffer.writeString("AUTHENTICATE ") +
            self.buffer.writeAuthenticationMechanism(mechanism) +
            self.buffer.writeIfExists(initialResponse) { resp in
                self.buffer.writeSpace() +
                    self.buffer.writeInitialResponse(resp)
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

    private mutating func writeCommandKind_uidExpunge(_ set: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>) -> Int {
        self.buffer.writeString("EXPUNGE ") +
            self.buffer.writeLastCommandSet(set)
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

    private mutating func writeCommandKind_copy(set: LastCommandSet<SequenceRangeSet>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("COPY ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidCopy(set: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID COPY ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_fetch(set: LastCommandSet<SequenceRangeSet>, atts: [FetchAttribute], modifiers: OrderedDictionary<String, ParameterValue?>) -> Int {
        self.buffer.writeString("FETCH ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeFetchAttributeList(atts) +
            self.buffer.writeIfExists(modifiers) { (modifiers) -> Int in
                self.buffer.writeParameters(modifiers)
            }
    }

    private mutating func writeCommandKind_uidFetch(set: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, atts: [FetchAttribute], modifiers: OrderedDictionary<String, ParameterValue?>) -> Int {
        self.buffer.writeString("UID FETCH ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeFetchAttributeList(atts) +
            self.buffer.writeIfExists(modifiers) { (modifiers) -> Int in
                self.buffer.writeParameters(modifiers)
            }
    }

    private mutating func writeCommandKind_store(set: LastCommandSet<SequenceRangeSet>, modifiers: [StoreModifier], data: StoreData) -> Int {
        self.buffer.writeString("STORE ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.write(if: modifiers.count >= 1) {
                self.buffer.writeSpace() +
                    self.buffer.writeArray(modifiers) { (element, buffer) -> Int in
                        buffer.writeStoreModifier(element)
                    }
            } +
            self.buffer.writeSpace() +
            self.buffer.writeStoreData(data)
    }

    private mutating func writeCommandKind_uidStore(set: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, modifiers: OrderedDictionary<String, ParameterValue?>, data: StoreData) -> Int {
        self.buffer.writeString("UID STORE ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.write(if: modifiers.count >= 1) {
                self.buffer.writeParameters(modifiers)
            } +
            self.buffer.writeSpace() +
            self.buffer.writeStoreData(data)
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

    private mutating func writeCommandKind_move(set: LastCommandSet<SequenceRangeSet>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("MOVE ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_uidMove(set: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, mailbox: MailboxName) -> Int {
        self.buffer.writeString("UID MOVE ") +
            self.buffer.writeLastCommandSet(set) +
            self.buffer.writeSpace() +
            self.buffer.writeMailbox(mailbox)
    }

    private mutating func writeCommandKind_namespace() -> Int {
        self.buffer.writeNamespaceCommand()
    }

    @discardableResult mutating func writeCommandKind_id(_ id: OrderedDictionary<String, String?>) -> Int {
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
            self.buffer.writeArray(resourceLimits) { (limit, self) in
                self.writeQuotaLimit(limit)
            }
    }

    private mutating func writeCommandKind_extendedSearch(options: ExtendedSearchOptions) -> Int {
        self.buffer.writeString("ESEARCH") +
            self.buffer.writeExtendedSearchOptions(options)
    }
}

// MARK: - Conveniences

extension Command {
    /// Convenience for creating a *UID MOVE* command.
    /// Pass in a `UIDSet`, and if that set is valid (i.e. non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter mailbox: The destination mailbox.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidMove(messages: MessageIdentifierSet<UID>, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidMove(.set(set), mailbox)
    }

    /// Convenience for creating a *UID COPY* command.
    /// Pass in a `UIDSet`, and if that set is valid (i.e. non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter mailbox: The destination mailbox.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidCopy(messages: MessageIdentifierSet<UID>, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidCopy(.set(set), mailbox)
    }

    /// Convenience for creating a *UID FETCH* command.
    /// Pass in a `UIDSet`, and if that set is valid (i.e. non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter attributes: Which attributes to retrieve.
    /// - parameter modifiers: Fetch modifiers.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidFetch(messages: MessageIdentifierSet<UID>, attributes: [FetchAttribute], modifiers: OrderedDictionary<String, ParameterValue?>) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidFetch(.set(set), attributes, modifiers)
    }

    /// Convenience for creating a *UID STORE* command.
    /// Pass in a `UIDSet`, and if that set is valid (i.e. non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - parameter modifiers: Store modifiers.
    /// - parameter flags: The flags to store.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidStore(messages: MessageIdentifierSet<UID>, modifiers: OrderedDictionary<String, ParameterValue?>, data: StoreData) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidStore(.set(set), modifiers, data)
    }

    /// Convenience for creating a *UID EXPUNGE* command.
    /// Pass in a `UIDSet`, and if that set is valid (i.e. non-empty) then a command is returned.
    /// - parameter messages: The set of message UIDs to use.
    /// - returns: `nil` if `messages` is empty, otherwise a `Command`.
    public static func uidExpunge(messages: MessageIdentifierSet<UID>, mailbox: MailboxName) -> Command? {
        guard let set = MessageIdentifierSetNonEmpty(set: messages) else {
            return nil
        }
        return .uidExpunge(.set(set))
    }
}
